//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./internal-upgradeable/BaseUpgradeable.sol";
import "./internal-upgradeable/ReferralUpgradeable.sol";
import "./internal-upgradeable/SignableUpgradeable.sol";
import "./internal-upgradeable/TransferableUpgradeable.sol";
import "./internal-upgradeable/FundForwarderUpgradeable.sol";

import "./interfaces/IBet2WinUpgradeable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-IERC20PermitUpgradeable.sol";

import "./libraries/Array.sol";
import {BetLogic} from "./libraries/Bet2WinLogic.sol";
import {Encoder} from "./libraries/Bet2WinEncoder.sol";

import "@openzeppelin/contracts-upgradeable/utils/structs/BitMapsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

contract Bet2WinUpgradeable is
    BaseUpgradeable,
    ReferralUpgradeable,
    SignableUpgradeable,
    TransferableUpgradeable,
    FundForwarderUpgradeable,
    IBet2WinUpgradeable
{
    using Array for uint256[];
    using Encoder for uint256;
    using FixedPointMathLib for uint256;
    using BitMapsUpgradeable for BitMapsUpgradeable.BitMap;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    /// @dev value is equal to keccak256("Bet2Win_v2")
    bytes32 public constant VERSION =
        0x8e3e823de2bb7c24984bbbe5a5f367858a2b2a0e1acc8a6596d09460976a21a4;

    uint256 public constant MAX_TEAM_SLOTS = 32;
    uint256 public constant REFERRAL_PERCENT = 250;
    uint256 public constant HOUSE_EDGE_PERCENT = 250;

    /// @dev size in USD
    uint256 public constant MINIMUM_SIZE = 5 ether;
    uint256 public constant MAXIMUM_SIZE = 10_000 ether;
    /// @dev odds can be up to 10x
    uint256 public constant MAXIMUM_ODD = 1000_000;
    uint256 public constant PERCENTAGE_FRACTION = 10_000;
    uint256 public constant WITHDRAWAL_THRESHOLD = 1 ether;

    /// @dev value is equal to keccak256("Permit(address user,address referrer,uint256 betId,uint256 amount,address paymentToken,uint256 deadline,uint256 nonce)")
    bytes32 private constant __PERMIT_TYPE_HASH =
        0xec561885ee9ae4b4f381365f2074cf03880c53581b096eb22f48087bfda5e58c;

    IERC20Upgradeable public rewardToken;
    IUniswapV2Pair public reward2USDPair;
    /// @dev convert native token to USD price
    AggregatorV3Interface public native2USD;

    uint8[] private __gameIds;
    uint8[] private __betTypes;
    uint8[] private __settleStatuses;
    mapping(uint8 => uint24[]) private __matchIds;
    EnumerableSetUpgradeable.AddressSet private __users;

    BitMapsUpgradeable.BitMap private __paidReceipts;

    //  concat(matchId, gameId) => settleStatus => scores
    mapping(uint32 => mapping(uint8 => uint256)) private __resolves;
    //  gambler => key(matchId, gameId, settleStatus, betType) => (sideAgainst, amount, odd)[32]
    mapping(address => mapping(uint48 => uint128[32])) private __bets;

    function initialize(
        uint16[] calldata levelBonusRates_,
        IAuthority authority_,
        ITreasury treasury_,
        IUniswapV2Pair pair_,
        IERC20Upgradeable rewardToken_,
        AggregatorV3Interface priceFeed_
    ) external initializer {
        native2USD = priceFeed_;
        rewardToken = rewardToken_;
        reward2USDPair = pair_;

        __Signable_init("Bet2Win", "2");
        __FundForwarder_init_unchained(treasury_);
        __Referral_init_unchained(levelBonusRates_);
        __Base_init_unchained(authority_, Roles.TREASURER_ROLE);
    }

    function withdrawBonus() external {
        address sender = _msgSender();
        uint256 amount = bonuses[sender];
        require(amount >= WITHDRAWAL_THRESHOLD, "BET2WIN: NOT_ENOUGH_VALUE");

        delete bonuses[sender];

        _safeTransfer(rewardToken, sender, amount);
    }

    function updateRewardPair(IUniswapV2Pair pair_)
        external
        onlyRole(Roles.OPERATOR_ROLE)
    {
        reward2USDPair = pair_;
    }

    function addReferrer(address referrer_, address referree_)
        external
        override
        onlyRole(Roles.OPERATOR_ROLE)
    {
        _addReferrer(referrer_, referree_);
    }

    function resolveMatch(
        uint32 gameId_,
        uint24 matchId_,
        uint8 status_,
        uint256 scores_
    ) external onlyRole(Roles.CROUPIER_ROLE) {
        __resolves[(gameId_ << 24) | matchId_][status_] = scores_;
    }

    function placeBet(
        uint256 betId_,
        uint256 deadline_,
        bytes calldata signature_,
        Payment calldata payment_
    ) external payable whenNotPaused returns (bool isNewUserAdded) {
        address gambler = _msgSender();
        _checkBlacklist(gambler);
        _onlyEOA(gambler);
        isNewUserAdded = __users.add(gambler);

        __checkSignature(gambler, betId_, payment_, deadline_, signature_);
        __processPayment(gambler, payment_);
        __processBet(gambler, betId_, payment_);

        if (payment_.referrer != address(0))
            _addReferrer(payment_.referrer, gambler);
    }

    function settleBet(
        uint32 gameId_,
        uint24 matchId_,
        uint8 status_,
        uint8 betType_,
        uint8 side_
    ) external whenNotPaused {
        uint256 scores = __resolves[(gameId_ << 24) | matchId_][status_];
        require(scores != 0, "BET2WIN: UNSETTLE_BET");

        uint48 id = Encoder.toUniqueKey(gameId_, matchId_, status_, betType_);
        address gambler = _msgSender();
        uint256 betDetail = __bets[gambler][id][side_];
        require(betDetail != 0, "BET2WIN: UNEXIST_BET");

        require(
            BetLogic.isValidClaim(
                side_,
                betDetail.sideAgainst(),
                betType_,
                betDetail.betData(),
                scores
            ),
            "BET2WIN: INVALID_CLAIM"
        );

        uint256 receipt = Encoder.receiptOf(gambler, id, side_);
        require(!__paidReceipts.get(receipt), "BET2WIN: ALREADY_PAID");
        __paidReceipts.set(receipt);

        uint256 received;
        {
            (uint256 res0, uint256 res1, ) = reward2USDPair.getReserves();
            IERC20Upgradeable _rewardToken = rewardToken;
            uint256 referralPercent = REFERRAL_PERCENT;
            uint256 remainOdd = betDetail.odd() -
                HOUSE_EDGE_PERCENT -
                referralPercent;
            uint256 amount = betDetail.amount().mulDivDown(res0, res1);
            uint256 percentageFraction = PERCENTAGE_FRACTION;
            received = amount.mulDivDown(remainOdd, percentageFraction);
            _safeTransfer(_rewardToken, gambler, received);
            _updateReferrerBonus(
                gambler,
                amount.mulDivDown(referralPercent, percentageFraction)
            );
        }

        emit BetSettled(gambler, id, side_, receipt, received);
    }

    function __processBet(
        address gambler_,
        uint256 betId_,
        Payment calldata payment_
    ) private {
        (
            uint8 gameId,
            uint24 matchId,
            uint24 odd,
            uint16 betData,
            uint8 settleStatus,
            uint8 side,
            uint8 sideAgainst,
            uint8 betType
        ) = Encoder.decodeBetId(betId_);

        require(
            sideAgainst < MAX_TEAM_SLOTS && odd < MAXIMUM_ODD,
            "BET2WIN: INVALID_ARGUMENT"
        );

        uint48 id = Encoder.toUniqueKey(gameId, matchId, settleStatus, betType);
        uint256 usdSize = payment_.amount;
        {
            uint256 betDetail = __bets[gambler_][id][side];
            if (betDetail != 0)
                require(odd <= betDetail.odd(), "BET2WIN: INVALID_ODD");

            unchecked {
                if (payment_.token == address(0)) {
                    (, int256 usdUnit, , , ) = native2USD.latestRoundData();
                    usdSize += (betDetail.amount() * uint256(usdUnit)) / 1e8;
                } else usdSize += betDetail.amount();
            }
        }

        require(
            usdSize >= MINIMUM_SIZE && usdSize <= MAXIMUM_SIZE,
            "BET2WIN: BETSIZE_OUT_OF_BOUNDS"
        );

        __bets[gambler_][id][side] = Encoder.toBetDetail(
            usdSize,
            sideAgainst,
            betData,
            odd
        );

        __gameIds.push(gameId);
        __betTypes.push(betType);
        __matchIds[gameId].push(matchId);
        __settleStatuses.push(settleStatus);

        emit BetPlaced(gambler_, id, side, settleStatus, odd, usdSize);
    }

    function __checkSignature(
        address gambler_,
        uint256 betId_,
        Payment calldata payment_,
        uint256 deadline_,
        bytes calldata signature_
    ) private {
        require(block.timestamp < deadline_, "BET2WIN: EXPIRED");
        bytes32 structHash = keccak256(
            abi.encode(
                __PERMIT_TYPE_HASH,
                gambler_,
                payment_.referrer,
                betId_,
                payment_.amount,
                payment_.token,
                deadline_,
                _useNonce(gambler_)
            )
        );
        require(
            _hasRole(Roles.SIGNER_ROLE, _recoverSigner(structHash, signature_)),
            "BET2WIN: INVALID_SIGNATURE"
        );
    }

    function __processPayment(address gambler_, Payment calldata payment_)
        private
    {
        ITreasury _treasury = treasury();
        address paymentToken = payment_.token;
        require(
            _treasury.supportedPayment(paymentToken),
            "BET2WIN: UNSUPPORTED_PAYMENT"
        );

        uint256 amount = payment_.amount;
        if (paymentToken != address(0)) {
            require(payment_.deadline > block.timestamp, "BET2WIN: EXPIRED");

            IERC20PermitUpgradeable(paymentToken).permit(
                gambler_,
                address(this),
                amount,
                payment_.deadline,
                payment_.v,
                payment_.r,
                payment_.s
            );

            if (msg.value != 0) _safeNativeTransfer(gambler_, msg.value);
        } else if (msg.value > amount) {
            unchecked {
                _safeNativeTransfer(gambler_, msg.value - amount);
            }
        }

        _safeTransferFrom(
            IERC20Upgradeable(paymentToken),
            gambler_,
            address(_treasury),
            amount
        );
    }

    function updateTreasury(ITreasury treasury_)
        external
        override(FundForwarderUpgradeable, IFundForwarderUpgradeable)
        onlyRole(Roles.OPERATOR_ROLE)
    {
        emit TreasuryUpdated(treasury(), treasury_);
        _updateTreasury(treasury_);
    }

    function estimateRewardReceive(uint256 betSize_, uint256 odd_)
        external
        view
        returns (uint256)
    {
        (uint256 res0, uint256 res1, ) = reward2USDPair.getReserves();
        IERC20Upgradeable _rewardToken = rewardToken;
        res0 *= 10**IERC20MetadataUpgradeable(address(_rewardToken)).decimals();

        uint256 referralPercent = REFERRAL_PERCENT;
        uint256 remainOdd = odd_ - HOUSE_EDGE_PERCENT - referralPercent;

        uint256 amount = (betSize_ * res0) / res1;
        return amount.mulDivDown(remainOdd, PERCENTAGE_FRACTION);
    }

    /// @inheritdoc IBet2WinUpgradeable
    function users() external view returns (address[] memory) {
        return __users.values();
    }

    function settleStatuses() external view returns (uint256[] memory) {
        uint256[] memory data;
        uint8[] memory matchIds = __settleStatuses;
        assembly {
            data := matchIds
        }
        return data.buildSet();
    }

    function betTypes() external view returns (uint256[] memory) {
        uint256[] memory data;
        uint8[] memory matchIds = __betTypes;
        assembly {
            data := matchIds
        }
        return data.buildSet();
    }

    function betOf(
        address gambler_,
        uint256 gameId_,
        uint256 matchId_,
        uint256 status_,
        uint256 betType_,
        uint256 betSide_
    )
        external
        view
        returns (
            uint256 betSize,
            uint256 sideAgainst,
            uint256 betData,
            uint256 odd
        )
    {
        uint256 betDetail = __bets[gambler_][
            Encoder.toUniqueKey(gameId_, matchId_, status_, betType_)
        ][betSide_];
        betSize = betDetail.amount();
        sideAgainst = betDetail.sideAgainst();
        betData = betData.betData();
        odd = betData.odd();
    }

    /// @inheritdoc IBet2WinUpgradeable
    function matchesIds(uint8 gameId_)
        external
        view
        returns (uint256[] memory)
    {
        uint256[] memory data;
        uint24[] memory matchIds = __matchIds[gameId_];
        assembly {
            data := matchIds
        }
        return data.buildSet();
    }

    /// @inheritdoc IBet2WinUpgradeable
    function gameIds() external view returns (uint256[] memory) {
        uint256[] memory data;
        uint8[] memory _gameIds = __gameIds;
        assembly {
            data := _gameIds
        }
        return data.buildSet();
    }

    function betIdOf(
        uint104 gameId_,
        uint96 matchId_,
        uint72 odd_,
        uint48 betData_,
        uint32 settleStatus_,
        uint24 side_,
        uint16 sideAgainst_,
        uint8 betType_
    ) external pure returns (uint256) {
        uint256 a = (gameId_ << 96) | (matchId_ << 72);
        uint256 b = (odd_ << 48) | (betData_ << 32);
        uint256 c = (settleStatus_ << 24) | (side_ << 16);
        uint256 d = (sideAgainst_ << 8) | betType_;
        return a | b | c | d;
    }

    uint256[39] private __gap;
}

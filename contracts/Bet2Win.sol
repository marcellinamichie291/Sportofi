//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./internal-upgradeable/BaseUpgradeable.sol";
import "./internal-upgradeable/SignableUpgradeable.sol";
import "./internal-upgradeable/ProxyCheckerUpgradeable.sol";
import "./internal-upgradeable/TransferableUpgradeable.sol";
import "./internal-upgradeable/FundForwarderUpgradeable.sol";

import "./interfaces/IBet2Win.sol";

import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/BitMapsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-IERC20PermitUpgradeable.sol";

import "./libraries/Array.sol";

contract Bet2Win is
    BaseUpgradeable,
    SignableUpgradeable,
    ProxyCheckerUpgradeable,
    TransferableUpgradeable,
    FundForwarderUpgradeable,
    IBet2Win,
    ReentrancyGuardUpgradeable
{
    using Array for uint256[];
    using Bytes32Address for address;
    using MathUpgradeable for uint256;
    using SafeCastUpgradeable for uint256;
    using BitMapsUpgradeable for BitMapsUpgradeable.BitMap;

    /// @dev value is equal to keccak256("Bet2Win_v1")
    bytes32 public constant VERSION =
        0xabde44f121d3d3a0bf9cd3c0b366523a0245d2c5d7fbb7f38526cd42d522e6af;

    uint256 public constant REFERAL_PERCENT = 250;
    uint256 public constant HOUSE_EDGE_PERCENT = 250;

    uint256 public constant MINIMUM_SIZE = 1 ether;
    uint256 public constant MAXIMUM_SIZE = 50 ether;
    /// @dev odds can be up to 10x
    uint256 public constant MAXIMUM_ODD = 1000_000;
    uint256 public constant PERCENTAGE_FRACTION = 10_000;

    /// @dev value is equal to keccak256("Permit(address user,uint256 betId,uint256 amount,address paymentToken,uint256 deadline,uint256 nonce)")
    bytes32 private constant __PERMIT_TYPE_HASH =
        0xe5e51ef2e78cfc0f352bab62ce7f0638fbc905821e660a187064efd4453c4e22;

    IERC20Upgradeable public rewardToken;
    AggregatorV3Interface public priceFeed;

    uint8[] private __gameIds;
    address[] private __users;
    mapping(uint256 => uint48[]) private __matchIds;

    BitMapsUpgradeable.BitMap private __paidReceipts;

    //  gambler => referree
    mapping(address => address) public referrals;
    //  gambler => key(matchId, gameId) => Bet
    mapping(address => mapping(uint256 => Bet)) private __bets;
    //  key(matchId, gameId) => status => sideInFavor
    mapping(uint256 => mapping(uint256 => uint256)) private __resolves;

    bytes32[] private __userList;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() payable {
        _disableInitializers();
    }

    /// @inheritdoc IBet2Win
    function initialize(
        IAuthority authority_,
        ITreasury treasury_,
        IERC20Upgradeable rewardToken_,
        AggregatorV3Interface priceFeed_
    ) external override initializer {
        priceFeed = priceFeed_;
        rewardToken = rewardToken_;
        __ReentrancyGuard_init();
        __FundForwarder_init(treasury_);
        __Base_init(authority_, Roles.TREASURER_ROLE);
    }

    /// @inheritdoc IBet2Win
    function addReferree(address user_, address referree_)
        external
        onlyRole(Roles.CROUPIER_ROLE)
    {
        _checkBlacklist(referree_);
        _onlyEOA(referree_);

        referrals[user_] = referree_;

        emit ReferreeAdded(user_, referree_);
    }

    /// @inheritdoc IBet2Win
    function resolveMatch(
        uint256 gameId_,
        uint256 matchId_,
        uint256 status_,
        uint256 sideInFavor_
    ) external onlyRole(Roles.CROUPIER_ROLE) {
        require(sideInFavor_ != 0, "BET2WIN: INVALID_ARGUMENT");
        __resolves[key(gameId_, matchId_)][status_] = sideInFavor_;

        emit MatchResolved(gameId_, matchId_, status_);
    }

    /// @inheritdoc IBet2Win
    function placeBet(
        uint256 betId_,
        uint96 amount_,
        uint256 permitDeadline_,
        uint256 croupierDeadline_,
        uint8 v,
        bytes32 r,
        bytes32 s,
        IERC20Upgradeable paymentToken_,
        bytes calldata croupierSignature_
    ) external payable whenNotPaused {
        require(
            amount_ > MINIMUM_SIZE && amount_ < MAXIMUM_SIZE,
            "BET2WIN: AMOUNT_OUT_OF_BOUNDS"
        );

        address user = _msgSender();
        __userList.push(user.fillLast12Bytes());
        ///@dev get rid of stack too deep
        {
            _checkBlacklist(user);
            _onlyEOA(user);

            require(
                _hasRole(
                    Roles.SIGNER_ROLE,
                    _recoverSigner(
                        keccak256(
                            abi.encode(
                                __PERMIT_TYPE_HASH,
                                user,
                                betId_,
                                amount_,
                                paymentToken_,
                                block.timestamp > croupierDeadline_
                                    ? block.timestamp
                                    : croupierDeadline_,
                                _useNonce(user)
                            )
                        ),
                        croupierSignature_
                    )
                ),
                "BET2WIN: INVALID_SIGNATURE"
            );

            ITreasury _treasury = treasury();
            require(
                _treasury.supportedPayment(paymentToken_),
                "BET2WIN: UNSUPPORTED_PAYMENT"
            );
            if (v != 0) {
                IERC20PermitUpgradeable(address(paymentToken_)).permit(
                    user,
                    address(this),
                    amount_,
                    block.timestamp > permitDeadline_
                        ? block.timestamp
                        : permitDeadline_,
                    v,
                    r,
                    s
                );
            }
            _safeTransferFrom(paymentToken_, user, address(_treasury), amount_);
        }

        (
            uint256 id,
            uint48 odd,
            uint48 settleStatus,
            uint48 side
        ) = __decodeBetId(betId_);

        emit BetPlaced(user, id, side, settleStatus, odd);

        require(side != 0 && odd < MAXIMUM_ODD, "BET2WIN: INVALID_ARGUMENT");
        ///@dev get rid of stack too deep
        {
            uint8 gameId = uint8(id >> 48);
            __gameIds.push(gameId);
            __matchIds[gameId].push(uint48(id));
        }

        require(__bets[user][id].amount == 0, "BET2WIN: ALREADY_PLACED_BET");
        __bets[user][id] = Bet(
            settleStatus,
            side,
            odd,
            amount_,
            address(paymentToken_) == address(0) ? 2 : 1
        );
    }

    /// @inheritdoc IBet2Win
    function settleBet(
        uint256 gameId_,
        uint256 matchId_,
        uint256 status_
    ) external nonReentrant {
        _requireNotPaused();

        address user = _msgSender();
        uint256 id = key(gameId_, matchId_);
        Bet memory bet = __bets[user][id];
        require(bet.side == __resolves[id][status_], "BET2WIN: UNSETTLED_BET");

        uint256 receipt = __receiptOf(
            user,
            id,
            bet.odd,
            bet.side,
            bet.settleStatus
        );
        require(!__paidReceipts.get(receipt), "BET2WIN: ALREADY_PAID");
        __paidReceipts.set(receipt);
        address referree = referrals[user];
        emit BetSettled(receipt, user, referree);

        uint256 leverage = referree == address(0)
            ? bet.odd - HOUSE_EDGE_PERCENT
            : bet.odd - HOUSE_EDGE_PERCENT - REFERAL_PERCENT;
        uint256 amount = bet.amount;
        if (bet.isNativePayment == 2) {
            (, int256 usdPrice, , , ) = priceFeed.latestRoundData();
            amount *= uint256(usdPrice / 1e8);
        }

        /// @dev caching to save gas if has referree
        IERC20Upgradeable _rewardToken = rewardToken;
        _safeTransfer(
            _rewardToken,
            user,
            amount.mulDiv(
                leverage,
                PERCENTAGE_FRACTION,
                MathUpgradeable.Rounding.Down
            )
        );
        if (referree != address(0))
            _safeTransfer(
                _rewardToken,
                referree,
                amount.mulDiv(
                    REFERAL_PERCENT,
                    PERCENTAGE_FRACTION,
                    MathUpgradeable.Rounding.Down
                )
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

    /// @inheritdoc IBet2Win
    function users() external view returns (address[] memory) {
        uint256[] memory data;
        assembly {
            data := sload(__userList.slot)
        }
        data = data.buildSet();
        address[] memory setUsers = new address[](data.length);
        assembly {
            setUsers := data
        }
        return setUsers;
    }

    /// @inheritdoc IBet2Win
    function betOf(
        address gambler_,
        uint256 gameId_,
        uint256 matchId_
    ) external view returns (Bet memory) {
        return __bets[gambler_][key(gameId_, matchId_)];
    }

    /// @inheritdoc IBet2Win
    function matchesIds(uint256 gameId_)
        external
        view
        returns (uint48[] memory)
    {
        uint256[] memory data;
        assembly {
            mstore(0x00, gameId_)
            mstore(0x20, __matchIds.slot)
            data := sload(keccak256(0x00, 0x40))
        }
        data = data.buildSet();
        uint48[] memory setMatchIds = new uint48[](data.length);
        assembly {
            setMatchIds := data
        }
        return setMatchIds;
    }

    /// @inheritdoc IBet2Win
    function gameIds() external view returns (uint8[] memory) {
        uint256[] memory data;
        assembly {
            data := sload(__gameIds.slot)
        }
        data = data.buildSet();
        uint8[] memory setGameIds = new uint8[](data.length);
        assembly {
            setGameIds := data
        }
        return setGameIds;
    }

    /// @inheritdoc IBet2Win
    function key(uint256 gameId_, uint256 matchId_)
        public
        pure
        returns (uint256)
    {
        return (gameId_ << 48) | matchId_;
    }

    /// @inheritdoc IBet2Win
    function betIdOf(
        uint256 gameId_,
        uint256 matchId_,
        uint256 odd_,
        uint256 settleStatus_,
        uint256 side_
    ) external pure returns (uint256) {
        return
            (gameId_ << 192) |
            (matchId_ << 144) |
            (odd_ << 96) |
            (settleStatus_ << 48) |
            side_;
    }

    function __decodeBetId(uint256 betId_)
        private
        pure
        returns (
            uint256 id,
            uint48 odd,
            uint48 settleStatus,
            uint48 side
        )
    {
        assembly {
            odd := shr(96, betId_)
            settleStatus := shr(48, betId_)
            side := betId_
        }
        id = key(betId_ >> 192, (betId_ >> 144) & ~uint48(0));
    }

    function __receiptOf(
        address user_,
        uint256 id_,
        uint256 odd_,
        uint256 side_,
        uint256 settleStatus_
    ) private pure returns (uint256) {
        uint256 digest;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, user_)
            mstore(add(ptr, 0x20), id_)
            mstore(add(ptr, 0x40), odd_)
            mstore(add(ptr, 0x60), side_)
            mstore(add(ptr, 0x80), settleStatus_)
            digest := keccak256(ptr, 0xa0)
        }
        return digest;
    }

    uint256[40] private __gap;
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./internal-upgradeable/BaseUpgradeable.sol";
import "./internal-upgradeable/SignableUpgradeable.sol";
import "./internal-upgradeable/ProxyCheckerUpgradeable.sol";
import "./internal-upgradeable/TransferableUpgradeable.sol";
import "./internal-upgradeable/FundForwarderUpgradeable.sol";

import "./interfaces/IBet2Win.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/BitMapsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-IERC20PermitUpgradeable.sol";

contract Bet2WinUpgradeable is
    BaseUpgradeable,
    SignableUpgradeable,
    ProxyCheckerUpgradeable,
    TransferableUpgradeable,
    FundForwarderUpgradeable,
    IBet2Win
{
    using MathUpgradeable for uint256;
    using SafeCastUpgradeable for uint256;
    using BitMapsUpgradeable for BitMapsUpgradeable.BitMap;
    using CountersUpgradeable for CountersUpgradeable.Counter;
    //using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
    //using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    ///@dev value is equal to keccak256("Bet2Win_v1")
    bytes32 public constant VERSION =
        0xabde44f121d3d3a0bf9cd3c0b366523a0245d2c5d7fbb7f38526cd42d522e6af;

    uint256 public constant REFERAL_PERCENT = 250;
    uint256 public constant HOUSE_EDGE_PERCENT = 250;

    uint256 public constant MINIMUM_SIZE = 1 ether;
    uint256 public constant MAXIMUM_SIZE = 50 ether;
    uint256 public constant MAXIMUM_ODD = 1000_000;
    uint256 public constant PERCENTAGE_FRACTION = 10_000;

    // IERC20Upgradeable public constant REWARD_TOKEN =
    //     IERC20Upgradeable(0x7976950DdCC0B7b3Ac0d9bCd77CABD0a2662CaDB);

    ///@dev value is equal to keccak256("Permit(address user,uint256 betId,uint256 amount,address paymentToken,uint256 deadline,uint256 nonce)")
    bytes32 private constant __PERMIT_TYPE_HASH =
        0xe5e51ef2e78cfc0f352bab62ce7f0638fbc905821e660a187064efd4453c4e22;

    string private constant __AMOUNT_OUT_OF_BOUNDS =
        "BET2WIN: AMOUNT_OUT_OF_BOUNDS";

    IERC20Upgradeable public immutable token;
    AggregatorV3Interface public immutable priceFeed;

    BitMapsUpgradeable.BitMap private __paidReceipts;
    //EnumerableSetUpgradeable.UintSet private __gameIds;
    //EnumerableSetUpgradeable.AddressSet private __users;
    uint48[] private __gameIds;
    address[] private __users;

    //gambler => referree
    mapping(address => address) public referrals;
    //gambler => key(matchId, gameId) => Bet
    mapping(address => mapping(uint256 => Bet)) private __bets;

    // //key(matchId, gameId) => amountsBetted
    // mapping(uint256 => uint256) private __lockedInBets;
    //key(matchId, gameId) => status => sideInFavor
    mapping(uint256 => mapping(uint256 => uint256)) private __resolves;
    // //key(matchId, gameId) => number of gamblers
    // mapping(uint256 => CountersUpgradeable.Counter) private __gamblerPools;
    //gameId => matchIds
    //mapping(uint256 => EnumerableSetUpgradeable.UintSet) private __matchIds;
    mapping(uint256 => uint48[]) private __matchIds;

    constructor(
        IGovernance governance_,
        ITreasury treasury_,
        IERC20Upgradeable token_,
        AggregatorV3Interface priceFeed_
    ) initializer {
        token = token_;
        priceFeed = priceFeed_;
        __updateGovernance(governance_);
        _updateTreasury(treasury_);

        governance().requestAccess(Roles.TREASURER_ROLE);
        //_disableInitializers();
    }

    function initialize(IGovernance governance_, ITreasury treasury_)
        external
        initializer
    {
        __Base_init(governance_, Roles.TREASURER_ROLE);
        __FundForwarder_init(treasury_);
    }

    function addReferree(address user_, address referree_)
        external
        onlyRole(Roles.CROUPIER_ROLE)
    {
        _checkBlacklist(referree_);
        _onlyEOA(referree_);

        referrals[user_] = referree_;

        emit ReferreeAdded(user_, referree_);
    }

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
    ) external payable {
        _requireNotPaused();

        require(
            amount_ >= MINIMUM_SIZE && amount_ <= MAXIMUM_SIZE,
            "BET2WIN: AMOUNT_OUT_OF_BOUNDS"
        );

        address user = _msgSender();
        __users.push(user);
        ///@dev get rid of stack too deep
        {
            _checkBlacklist(user);
            _onlyEOA(user);

            __checkDeadline(croupierDeadline_);
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
                                croupierDeadline_,
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
                __checkDeadline(permitDeadline_);
                (bool ok, ) = address(paymentToken_).call(
                    abi.encodeCall(
                        IERC20PermitUpgradeable.permit,
                        (user, address(this), amount_, permitDeadline_, v, r, s)
                    )
                );
                require(ok, "BET2WIN: PERMISSION_DENIED");
            }
            _safeTransferFrom(paymentToken_, user, address(_treasury), amount_);
        }

        (
            uint256 id,
            uint64 odd,
            uint8 settleStatus,
            uint8 side
        ) = __decodeBetId(betId_);
        emit BetPlaced(user, id, side, settleStatus, odd);

        require(side != 0 && odd < MAXIMUM_ODD, "BET2WIN: INVALID_ARGUMENT");
        ///@dev get rid of stack too deep
        {
            (uint48 gameId, uint48 matchId) = __decodeKey(id);
            __gameIds.push(gameId);
            __matchIds[gameId].push(matchId);
        }

        require(__bets[user][id].amount == 0, "BET2WIN: ALREADY_PLACED_BET");
        __bets[user][id] = Bet(
            settleStatus,
            side,
            odd,
            amount_,
            address(paymentToken_)
        );
    }

    function settleBet(
        uint256 gameId_,
        uint256 matchId_,
        uint256 status_
    ) external {
        _requireNotPaused();

        address user = _msgSender();
        uint256 id = key(gameId_, matchId_);
        Bet memory bet = __bets[user][id];
        uint256 sideInFavor = __resolves[id][status_];
        require(sideInFavor != 0, "BET2WIN: UNSETTLED_BET");
        require(bet.side == sideInFavor, "BET2WIN: INVALID_ARGUMENT");

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
        uint256 remainOdd = bet.odd - REFERAL_PERCENT - HOUSE_EDGE_PERCENT;
        uint256 leverage = referree != address(0)
            ? remainOdd - REFERAL_PERCENT
            : remainOdd;
        uint256 amount = bet.amount;
        if (bet.payment == address(0)) {
            (, int256 usdPrice, , , ) = priceFeed.latestRoundData();
            amount *= uint256(usdPrice) / 1 ether;
        }
            _safeTransfer(
                token,
                user,
                amount.mulDiv(
                    leverage,
                    PERCENTAGE_FRACTION,
                    MathUpgradeable.Rounding.Down
                )
            );
        if (referree != address(0))
            _safeTransfer(
                token,
                referree,
                amount.mulDiv(
                    REFERAL_PERCENT,
                    PERCENTAGE_FRACTION,
                    MathUpgradeable.Rounding.Down
                )
            );

        emit ReceiptPaid(receipt, user, referree);
    }

    function updateTreasury(ITreasury treasury_)
        external
        override(FundForwarderUpgradeable, IFundForwarderUpgradeable)
        onlyRole(Roles.OPERATOR_ROLE)
    {
        emit TreasuryUpdated(treasury(), treasury_);
        _updateTreasury(treasury_);
    }

    function users() external view returns (address[] memory) {
        return __users;
    }

    // function lockedInBets(uint256 gameId_, uint256 matchId_)
    //     external
    //     view
    //     returns (uint256)
    // {
    //     return __lockedInBets[key(gameId_, matchId_)];
    // }

    // function gamblerPool(uint256 gameId_, uint256 matchId_)
    //     external
    //     view
    //     returns (uint256)
    // {
    //     return __gamblerPools[key(gameId_, matchId_)].current();
    // }

    function betOf(
        address gambler_,
        uint256 gameId_,
        uint256 matchId_
    ) external view returns (Bet memory) {
        return __bets[gambler_][key(gameId_, matchId_)];
    }

    function matchesIds(uint256 gameId_)
        external
        view
        returns (uint48[] memory)
    {
        return __matchIds[gameId_];
    }

    function gameIds() external view returns (uint48[] memory) {
        return __gameIds;
    }

    function key(uint256 gameId_, uint256 matchId_)
        public
        pure
        returns (uint256)
    {
        return (gameId_ << 48) | matchId_.toUint48();
    }

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
            uint64 odd,
            uint8 settleStatus,
            uint8 side
        )
    {
        id = key(betId_ >> 192, (betId_ >> 144) & ~uint48(0));
        odd = uint64((betId_ >> 96) & ~uint48(0));
        settleStatus = uint8(betId_ >> 48);
        side = uint8(betId_);
    }

    function __decodeKey(uint256 id_)
        private
        pure
        returns (uint48 gameId, uint48 matchId)
    {
        gameId = uint48(id_ >> 48);
        matchId = uint48(id_);
    }

    function __receiptOf(
        address user_,
        uint256 id_,
        uint256 odd_,
        uint256 side_,
        uint256 settleStatus_
    ) private pure returns (uint256) {
        return
            uint256(
                (keccak256(abi.encode(user_, id_, odd_, side_, settleStatus_)))
            );
    }

    function __checkDeadline(uint256 deadline_) private view {
        require(block.timestamp < deadline_, "BET2WIN: EXPIRED_DEADLINE");
    }

    uint256[41] private __gap;
}

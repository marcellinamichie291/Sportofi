//SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./internal-upgradeable/BaseUpgradeable.sol";
import "./internal-upgradeable/SignableUpgradeable.sol";
import "./internal-upgradeable/ProxyCheckerUpgradeable.sol";
import "./internal-upgradeable/TransferableUpgradeable.sol";
import "./internal-upgradeable/FundForwarderUpgradeable.sol";

import "./interfaces/IBet2Win.sol";

import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/BitMapsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-IERC20PermitUpgradeable.sol";

contract Bet2WinUpgradeable is
    IBet2Win,
    BaseUpgradeable,
    SignableUpgradeable,
    ProxyCheckerUpgradeable,
    TransferableUpgradeable,
    FundForwarderUpgradeable
{
    using MathUpgradeable for uint256;
    using SafeCastUpgradeable for uint256;
    using BitMapsUpgradeable for BitMapsUpgradeable.BitMap;

    ///@dev value is equal to keccak256("Permit(address user,uint256 betId,uint256 amount,address paymentToken,uint256 deadline,uint256 nonce)")
    bytes32 private constant __PERMIT_TYPE_HASH =
        0xe5e51ef2e78cfc0f352bab62ce7f0638fbc905821e660a187064efd4453c4e22;

    uint256 public limit; // wei price

    BitMapsUpgradeable.BitMap private _paidReceipts;
    mapping(uint256 => mapping(uint256 => Game)) private _games;
    mapping(address => mapping(uint256 => Bet)) private _userBets;
    mapping(address => Bet[]) private _bets;

    function initialize(
        uint256 limit_,
        IGovernance governance_,
        ITreasury treasury_
    ) external initializer {
        __Base_init(governance_, 0);
        __FundForwarder_init(treasury_);

        __setLimit(limit_);
    }

    function createMatch(
        uint256 gameId_,
        uint256 matchId_,
        uint256 startTime_,
        uint256 openingTime_,
        uint256 maxOdd_
    ) external onlyRole(Roles.CROUPIER_ROLE) {}

    function setLimit(uint256 limit_) external onlyRole(Roles.OPERATOR_ROLE) {
        __setLimit(limit_);
    }

    function __setLimit(uint256 limit_) private {
        limit = limit_;
        emit LimitUpdated(limit_);
    }

    function placeBet(
        uint256 betId_,
        uint256 amount_,
        uint256 permitDeadline_,
        uint256 croupierDeadline_,
        uint8 v,
        bytes32 r,
        bytes32 s,
        IERC20Upgradeable paymentToken_,
        bytes calldata croupierSignature_
    ) external payable {
        _requireNotPaused();
        address user = _msgSender();
        ///@dev get rid of stack too deep
        {
            _onlyEOA(user);
            _checkBlacklist(user);

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
                    abi.encodeWithSelector(
                        IERC20PermitUpgradeable.permit.selector,
                        user,
                        address(this),
                        amount_,
                        permitDeadline_,
                        v,
                        r,
                        s
                    )
                );
                require(ok, "BET2WIN: PERMISSION_DENIED");
            }
            _safeTransferFrom(paymentToken_, user, address(_treasury), amount_);
        }
        (
            uint256 matchId,
            uint256 gameId,
            uint256 odd,
            uint256 side
        ) = __decodeBetId(betId_);
        __checkOnGoing(gameId, matchId);
        _userBets[user][(gameId << 128) | matchId] = Bet(
            uint96(amount_),
            uint80(side),
            uint80(odd)
        );

        emit BetPlaced(user, matchId, side, odd, gameId);
    }

    // function settleBet(uint256 gameId_, uint256 matchId_) external {
    //     address user = _msgSender();
    //     Bet memory bet = _userBets[user][(gameId_ << 128) | matchId_];
    // }

    function updateTreasury(ITreasury treasury_)
        external
        override
        onlyRole(Roles.OPERATOR_ROLE)
    {
        emit TreasuryUpdated(treasury(), treasury_);
        _updateTreasury(treasury_);
    }

    function getBetId(
        uint256 gameId_,
        uint256 matchId_,
        uint256 odd_,
        uint256 side_
    ) external pure returns (uint256) {
        return (gameId_ << 192) | (matchId_ << 128) | (odd_ << 64) | side_;
    }

    function __decodeBetId(uint256 betId_)
        private
        pure
        returns (
            uint256 gameId,
            uint256 matchId,
            uint256 odd,
            uint256 side
        )
    {
        gameId = betId_ >> 192;
        matchId = betId_ >> 128;
        odd = betId_ >> 64;
        side = betId_ & ~uint64(0);
    }

    function __getReceipt(
        address user_,
        uint256 gameId_,
        uint256 matchId_,
        uint256 side_,
        uint256 amount_
    ) private pure returns (uint256) {}

    function __checkOnGoing(uint256 gameId_, uint256 matchId_) private view {
        require(_games[gameId_][matchId_].start != 0, "BET2WIN: INVALID_ID");
    }

    function __checkDeadline(uint256 deadline_) private view {
        require(block.timestamp < deadline_, "BET2WIN: EXPIRED_DEADLINE");
    }
}

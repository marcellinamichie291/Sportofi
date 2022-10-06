// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../internal-upgradeable/interfaces/ISignableUpgradeable.sol";
import "../internal-upgradeable/interfaces/IFundForwarderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IBet2Win is ISignableUpgradeable, IFundForwarderUpgradeable {
    enum Status {
        STATUS_TBD,
        STATUS_FINAL,
        STATUS_FORFEIT,
        STATUS_DELAYED,
        STATUS_HALFTIME,
        STATUS_CANCELED, // refund
        STATUS_FINAL_PEN,
        STATUS_SCHEDULED,
        STATUS_ABANDONED, // refund
        STATUS_FULL_TIME,
        STATUS_POSTPONED,
        STATUS_PRE_FIGHT,
        STATUS_RAIN_DELAY,
        STATUS_FIRST_HALF,
        STATUS_END_PERIOD,
        STATUS_SECOND_HALF,
        STATUS_IN_PROGRESS,
        STATUS_UNCONTESTED,
        STATUS_END_OF_FIGHT,
        STATUS_END_OF_ROUND,
        STATUS_IN_PROGRESS_2,
        STATUS_FIGHTERS_WALKING,
        STATUS_FIGHTERS_INTRODUCTION
    }

    struct Bet {
        uint8 settleStatus;
        uint8 side;
        uint64 odd;
        uint96 amount;
        address payment;
    }

    event ReceiptPaid(
        uint256 indexed id,
        address indexed to,
        address indexed referree
    );

    event ReferreeAdded(address indexed user, address indexed referree);

    event BetPlaced(
        address indexed user,
        uint256 indexed id,
        uint256 indexed side,
        uint256 settleStatus,
        uint256 odd
    );

    event BetSettled();
    event MatchResolved(
        uint256 indexed gameId,
        uint256 indexed matchId,
        uint256 indexed status
    );

    function addReferree(address user_, address referree_) external;

    function resolveMatch(
        uint256 gameId_,
        uint256 matchId_,
        uint256 status_,
        uint256 sideInFavor_
    ) external;

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
    ) external payable;

    function settleBet(
        uint256 gameId_,
        uint256 matchId_,
        uint256 status_
    ) external;

    function users() external view returns (address[] memory);

    function betOf(
        address gambler_,
        uint256 gameId_,
        uint256 matchId_
    ) external view returns (Bet memory);

    function matchesIds(uint256 gameId_)
        external
        view
        returns (uint48[] memory);

    function gameIds() external view returns (uint48[] memory);

    function betIdOf(
        uint256 gameId_,
        uint256 matchId_,
        uint256 odd_,
        uint256 settleStatus_,
        uint256 side_
    ) external pure returns (uint256);
}

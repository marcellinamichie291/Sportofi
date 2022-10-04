// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IBet2Win {
    struct Game {
        uint32 gameId;
        uint64 start;
    }
    struct Bet {
        uint96 amount;
        uint80 side;
        uint80 odd;
    }
    struct Ticket {
        uint64 gameId;
        uint64 matchId;
        uint64 odd;
        uint64 side;
        uint96 amount;
        IERC20Upgradeable paymentToken;
    }

    event LimitUpdated(uint256 limit);

    event BetPlaced(
        address indexed user,
        uint256 indexed matchId,
        uint256 indexed side,
        uint256 odd,
        uint256 gameId
    );

    event BetSettled();
}

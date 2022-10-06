//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceFeed is AggregatorV3Interface {
    function latestRoundData()
        external
        pure
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        roundId = 36893488147419584297;
        answer = 29402624774;
        startedAt = 1665070299;
        updatedAt = 1665070299;
        answeredInRound = 36893488147419584297;
    }

    function decimals() external view returns (uint8) {}

    function description() external view returns (string memory) {}

    function getRoundData(uint80 _roundId)
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {}

    function version() external view returns (uint256) {}
}

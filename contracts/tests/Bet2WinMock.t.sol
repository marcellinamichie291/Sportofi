//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../Bet2Win.sol";

contract Bet2WinMock is Bet2Win {
    constructor(
        IAuthority authority_,
        ITreasury treasury_,
        IERC20Upgradeable token_,
        AggregatorV3Interface priceFeed_
    ) initializer {
        rewardToken = token_;
        priceFeed = priceFeed_;
        __updateAuthority(authority_);
        _updateTreasury(treasury_);

        authority().requestAccess(Roles.TREASURER_ROLE);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "../internal-upgradeable/interfaces/IFundForwarderUpgradeable.sol";

interface IHouseDeployer is IFundForwarderUpgradeable {
    function deploy(IERC20 rewardToken_, AggregatorV3Interface priceFeed_)
        external
        returns (address deployedAddr);

    function destroy() external;

    function instance() external view returns (address);
}

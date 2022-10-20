// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./internal-upgradeable/BaseUpgradeable.sol";
import "./internal-upgradeable/FactoryUpgradeable.sol";
import "./internal-upgradeable/FundForwarderUpgradeable.sol";

import {Bet2Win} from "./Bet2Win.sol";

import "./interfaces/IBet2Win.sol";
import "./interfaces/IHouseDeployer.sol";

import "./libraries/Bytes32Address.sol";

contract HouseDeployer is
    IHouseDeployer,
    BaseUpgradeable,
    FactoryUpgradeable,
    FundForwarderUpgradeable
{
    using Bytes32Address for address;
    using Bytes32Address for bytes32;

    /// @dev value is equal to keccak256("HouseDeployer_v2")
    bytes32 public constant VERSION =
        0xdaf43c9f251b3f135d330022c2424daf785cad61aeeed6956192a1352d18f04b;

    bytes32 private __instance;
    bytes32 private __proxy;
    uint256 private __destroyed;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() payable {
        _disableInitializers();
    }

    function initialize(IAuthority authority_, ITreasury treasury_)
        external
        initializer
    {
        __destroyed = 2;

        __FundForwarder_init(treasury_);
        __Base_init(authority_, Roles.FACTORY_ROLE);
    }

    function resetInstance() external onlyRole(Roles.OPERATOR_ROLE) {
        __instance = 0;
    }

    function deploy(IERC20 rewardToken_, AggregatorV3Interface priceFeed_)
        external
        onlyRole(Roles.OPERATOR_ROLE)
        returns (address deployedAddr)
    {
        require(__instance == 0, "HOUSE_DEPLOYER: ALREADY_DEPLOYED");
        deployedAddr = __deploy(rewardToken_, priceFeed_);
    }

    function __deploy(IERC20 rewardToken_, AggregatorV3Interface priceFeed_)
        private
        returns (address deployedAddr)
    {
        IAuthority _authority = authority();
        ITreasury _treasury = treasury();
        bytes32 salt = keccak256(
            abi.encodePacked(_authority, _treasury, address(this), VERSION)
        );
        address deployedProxy;
        (deployedAddr, deployedProxy) = _deploy(
            0,
            salt,
            abi.encodePacked(
                type(Bet2Win).creationCode,
                abi.encode(_authority, _treasury, rewardToken_, priceFeed_)
            )
        );
        __instance = deployedAddr.fillLast12Bytes();
        __destroyed = 1;
    }

    function destroy() external onlyRole(Roles.OPERATOR_ROLE) {
        __destroy();
    }

    function __destroy() private {
        IBet2Win(__instance.fromFirst20Bytes()).kill();
        __destroyed = 2;
    }

    function reinit(IERC20 rewardToken_, AggregatorV3Interface priceFeed_)
        external
        onlyRole(Roles.OPERATOR_ROLE)
        returns (address)
    {
        return __deploy(rewardToken_, priceFeed_);
    }

    function instance() public view returns (address) {
        return __instance.fromFirst20Bytes();
    }

    function updateTreasury(ITreasury treasury_)
        external
        override(FundForwarderUpgradeable, IFundForwarderUpgradeable)
        onlyRole(Roles.TREASURER_ROLE)
    {
        emit TreasuryUpdated(treasury(), treasury_);
        _updateTreasury(treasury_);
    }

    uint256[47] private __gap;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {VestingSchedule} from "./VestingSchedule.sol";

import "./internal-upgradeable/BaseUpgradeable.sol";
import "./internal-upgradeable/ProxylessUpgrader.sol";
import "./internal-upgradeable/FundForwarderUpgradeable.sol";

contract VestingFactory is
    BaseUpgradeable,
    ProxylessUpgrader,
    FundForwarderUpgradeable
{
    bytes32 public salt;

    function init(IAuthority authority_, ITreasury treasury_)
        external
        initializer
    {
        __FundForwarder_init_unchained(treasury_);
        __Base_init_unchained(authority_, Roles.FACTORY_ROLE);

        salt = keccak256(
            abi.encode(
                type(VestingFactory).name,
                address(this),
                authority_,
                treasury_
            )
        );
    }

    function destroy() external onlyRole(Roles.OPERATOR_ROLE) {
        _destroy();
    }

    function updateTreasury(ITreasury treasury_)
        external
        override
        onlyRole(Roles.OPERATOR_ROLE)
    {
        emit TreasuryUpdated(treasury(), treasury_);
        _updateTreasury(treasury_);
    }

    function deploy(bytes calldata initCode_)
        external
        onlyRole(Roles.OPERATOR_ROLE)
    {
        _deploy(
            0,
            salt,
            abi.encodePacked(type(VestingSchedule).creationCode, initCode_)
        );
    }

    function reinit(bytes calldata initCode_)
        external
        onlyRole(Roles.OPERATOR_ROLE)
    {
        require(
            address(instance).code.length == 0,
            "FACTORY: INSTANCE_EXISTED"
        );
        _deploy(
            0,
            salt,
            abi.encodePacked(type(VestingSchedule).creationCode, initCode_)
        );
    }

    uint256[49] private __gap;
}

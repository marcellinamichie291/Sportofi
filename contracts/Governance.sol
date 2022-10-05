// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

import "./internal-upgradeable/ProxyCheckerUpgradeable.sol";
import "./internal-upgradeable/BlacklistableUpgradeable.sol";

import "./libraries/Roles.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

import "./interfaces/IGovernance.sol";

contract GovernanceUpgradeable is
    IGovernance,
    UUPSUpgradeable,
    PausableUpgradeable,
    ProxyCheckerUpgradeable,
    BlacklistableUpgradeable,
    AccessControlEnumerableUpgradeable
{
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    bytes32 public constant VERSION =
        0xcab5b167ada4badb5ce0ed5f16a74aee744ece5365888dc008eb82537ed584dc;

    function init() external initializer {
        __Pausable_init();

        address sender = _msgSender();

        _grantRole(Roles.PAUSER_ROLE, sender);
        _grantRole(Roles.OPERATOR_ROLE, sender);
        _grantRole(Roles.UPGRADER_ROLE, sender);
        _grantRole(Roles.TREASURER_ROLE, sender);
        _grantRole(DEFAULT_ADMIN_ROLE, sender);

        _setRoleAdmin(Roles.OPERATOR_ROLE, Roles.PAUSER_ROLE);
        _setRoleAdmin(Roles.OPERATOR_ROLE, Roles.TREASURER_ROLE);
    }

    function requestAccess(bytes32 role) external override whenNotPaused {
        address origin = _txOrigin();
        _checkRole(Roles.OPERATOR_ROLE, origin);

        address sender = _msgSender();
        _onlyProxy(sender, origin);

        _grantRole(Roles.PROXY_ROLE, sender);
        if (role != 0) _grantRole(role, sender);

        emit ProxyAccessGranted(sender);
    }

    function pause() external override onlyRole(Roles.PAUSER_ROLE) {
        _pause();
    }

    function unpause() external override onlyRole(Roles.PAUSER_ROLE) {
        _unpause();
    }

    function paused()
        public
        view
        override(IGovernance, PausableUpgradeable)
        returns (bool)
    {
        return PausableUpgradeable.paused();
    }

    function setUserStatus(address account_, bool status_)
        external
        override(BlacklistableUpgradeable, IBlacklistableUpgradeable)
        whenPaused
        onlyRole(Roles.PAUSER_ROLE)
    {
        _setUserStatus(account_, status_);
        if (status_) emit Blacklisted(account_);
        else emit Whitelisted(account_);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        virtual
        override
        onlyRole(Roles.UPGRADER_ROLE)
    {}
}

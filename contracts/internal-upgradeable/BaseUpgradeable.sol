// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interfaces/IGovernance.sol";

import "../libraries/Roles.sol";

error Base__Paused();
error Base__Unpaused();
error Base__AlreadySet();
error Base__Unauthorized();
error Base__AuthorizeFailed();
error Base__UserIsBlacklisted();

abstract contract BaseUpgradeable is ContextUpgradeable, UUPSUpgradeable {
    bytes32 private _governance;

    event GovernanceUpdated(IGovernance indexed from, IGovernance indexed to);

    modifier onlyRole(bytes32 role) {
        _checkRole(role, _msgSender());
        _;
    }

    modifier onlyWhitelisted() {
        _checkBlacklist(_msgSender());
        _;
    }

    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    modifier whenPaused() {
        _requirePaused();
        _;
    }

    function updateGovernance(IGovernance governance_)
        external
        onlyRole(Roles.OPERATOR_ROLE)
    {
        IGovernance old = governance();
        if (old == governance_) revert Base__AlreadySet();
        __updateGovernance(governance_);
        emit GovernanceUpdated(old, governance_);
    }

    function governance() public view returns (IGovernance governance_) {
        assembly {
            governance_ := sload(_governance.slot)
        }
    }

    function __Base_init(IGovernance governance_, bytes32 role_)
        internal
        onlyInitializing
    {
        __Base_init_unchained(governance_, role_);
    }

    function __Base_init_unchained(IGovernance governance_, bytes32 role_)
        internal
        onlyInitializing
    {
        if (role_ != 0) {
            (bool ok, ) = address(governance_).call(
                abi.encodeWithSelector(
                    IGovernance.requestAccess.selector,
                    role_
                )
            );
            if (!ok) revert Base__AuthorizeFailed();
        }

        __updateGovernance(governance_);
    }

    function _checkBlacklist(address account_) internal view {
        if (governance().isBlacklisted(account_))
            revert Base__UserIsBlacklisted();
    }

    function _checkRole(bytes32 role_, address account_) internal view {
        if (!governance().hasRole(role_, account_)) revert Base__Unauthorized();
    }

    function __updateGovernance(IGovernance governance_) private {
        assembly {
            sstore(_governance.slot, governance_)
        }
    }

    function _requirePaused() internal view {
        if (!governance().paused()) revert Base__Unpaused();
    }

    function _requireNotPaused() internal view {
        if (governance().paused()) revert Base__Paused();
    }

    function _authorizeUpgrade(address implement_)
        internal
        virtual
        override
        onlyRole(Roles.UPGRADER_ROLE)
    {}

    function _hasRole(bytes32 role_, address account_)
        internal
        view
        returns (bool)
    {
        return governance().hasRole(role_, account_);
    }

    uint256[49] private __gap;
}

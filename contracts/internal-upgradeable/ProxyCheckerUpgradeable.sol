// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

error ProxyChecker__ProxyNotAllowed();
error ProxyChecker__OnlyProxyAllowed();

abstract contract ProxyCheckerUpgradeable is ContextUpgradeable {
    modifier onlyEOA() {
        _onlyEOA(_msgSender());
        _;
    }

    function __ProxyChecker_init() internal onlyInitializing {}

    function __ProxyChecker_init_unchained() internal onlyInitializing {}

    function _onlyEOA(address sender_) internal view {
        _onlyEOA(sender_, _txOrigin());
    }

    function _onlyEOA(address msgSender_, address txOrigin_) internal view {
        if (_isProxyCall(msgSender_, txOrigin_) || _isProxy(msgSender_))
            revert ProxyChecker__ProxyNotAllowed();
    }

    function _onlyProxy(address sender_) internal view {
        if (!_isProxyCall(sender_, _txOrigin()) && !_isProxy(sender_))
            revert ProxyChecker__OnlyProxyAllowed();
    }

    function _onlyProxy(address msgSender_, address txOrigin_) internal view {
        if (!_isProxyCall(msgSender_, txOrigin_) && !_isProxy(msgSender_))
            revert ProxyChecker__OnlyProxyAllowed();
    }

    function _isProxyCall(address msgSender_, address txOrigin_)
        internal
        pure
        returns (bool)
    {
        return msgSender_ != txOrigin_;
    }

    function _isProxy(address caller_) internal view returns (bool) {
        return caller_.code.length != 0;
    }

    function _txOrigin() internal view returns (address) {
        return tx.origin;
    }

    uint256[50] private _gap;
}

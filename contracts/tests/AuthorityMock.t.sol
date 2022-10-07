//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../Authority.sol";

contract AuthorityMock is Authority {
    constructor() initializer {
        address sender = _msgSender();

        _grantRole(Roles.PAUSER_ROLE, sender);
        _grantRole(Roles.OPERATOR_ROLE, sender);
        _grantRole(Roles.UPGRADER_ROLE, sender);
        _grantRole(Roles.TREASURER_ROLE, sender);
        _grantRole(DEFAULT_ADMIN_ROLE, sender);

        _setRoleAdmin(Roles.OPERATOR_ROLE, Roles.SIGNER_ROLE);
        _setRoleAdmin(Roles.OPERATOR_ROLE, Roles.PAUSER_ROLE);
        _setRoleAdmin(Roles.OPERATOR_ROLE, Roles.TREASURER_ROLE);
    }
}

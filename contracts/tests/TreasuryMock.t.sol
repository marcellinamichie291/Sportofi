//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../Treasury.sol";

contract TreasuryMock is Treasury {
    constructor(IAuthority authority_) initializer {
        __updateAuthority(authority_);
    }
}

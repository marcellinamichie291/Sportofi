//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    IERC20,
    IERC20Permit,
    ERC20,
    ERC20Permit,
    GovernanceToken
} from "../GovernanceToken.sol";

interface IPMToken is IERC20, IERC20Permit {
    function mint(address to_, uint256 amount_) external;
}

contract PMToken is ERC20Permit {
    constructor(string memory name_, string memory symbol_)
        ERC20(name_, symbol_)
        ERC20Permit(name_)
    {}

    function mint(address to_, uint256 amount_) external {
        _mint(to_, amount_ * 10**decimals());
    }
}

interface IGToken is IERC20, IERC20Permit {
    function mint(address to_, uint256 amount_) external;
}

contract GToken is GovernanceToken {
    constructor(string memory name_, string memory symbol_)
        GovernanceToken(name_, symbol_)
    {}

    function mint(address to_, uint256 amount_) external {
        _mint(to_, amount_ * 10**decimals());
    }
}

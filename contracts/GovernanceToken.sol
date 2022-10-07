//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract GovernanceToken is ERC20Capped, ERC20Burnable, ERC20Permit {
    constructor(string memory name_, string memory symbol_)
        ERC20(name_, symbol_)
        ERC20Permit(name_)
        ERC20Capped(2_000_000_000 * 10**decimals())
    {
        _mint(_msgSender(), 65_400_000 * 10**decimals());
    }

    function _mint(address to_, uint256 amount_)
        internal
        override(ERC20, ERC20Capped)
    {
        ERC20Capped._mint(to_, amount_);
    }
}

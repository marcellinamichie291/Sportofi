//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {
    ERC20,
    ERC20Permit
} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

import "./internal/Base.sol";
import "./internal/FundForwarder.sol";

contract GovernanceToken is Base, FundForwarder, ERC20Burnable, ERC20Permit {
    constructor(
        string memory name_,
        string memory symbol_,
        IAuthority authority_,
        ITreasury treasury_
    )
        payable
        ERC20Permit(name_)
        Base(authority_, 0)
        ERC20(name_, symbol_)
        FundForwarder(treasury_)
    {
        _mint(_msgSender(), 65_400_000 * 10**decimals());
    }

    function mint(address to_, uint256 amount_)
        external
        onlyRole(Roles.OPERATOR_ROLE)
    {
        _mint(to_, amount_ * 10**decimals());
    }

    function updateTreasury(ITreasury treasury_) external override {
        require(address(treasury_) != address(0), "VESTING: ZERO_ADDRESS");

        _updateTreasury(treasury_);

        emit TreasuryUpdated(treasury(), treasury_);
    }
}

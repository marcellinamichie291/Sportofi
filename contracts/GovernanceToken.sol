//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {
    ERC20,
    ERC20Permit
} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

import "./internal/FundForwarder.sol";

contract GovernanceToken is
    ERC20Permit,
    ERC20Pausable,
    ERC20Burnable,
    FundForwarder,
    AccessControlEnumerable
{
    /// @dev value is equal to keccak256("MINTER_ROLE")
    bytes32 public constant MINTER_ROLE =
        0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6;
    /// @dev value is equal to keccak256("PAUSER_ROLE")
    bytes32 public constant PAUSER_ROLE =
        0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a;
    /// @dev value is equal to keccak256("OPERATOR_ROLE")
    bytes32 public constant OPERATOR_ROLE =
        0x97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b929;

    constructor(
        string memory name_,
        string memory symbol_,
        ITreasury treasury_
    )
        payable
        ERC20Permit(name_)
        ERC20(name_, symbol_)
        FundForwarder(treasury_)
    {
        address sender = _msgSender();

        _grantRole(MINTER_ROLE, sender);
        _grantRole(PAUSER_ROLE, sender);
        _grantRole(OPERATOR_ROLE, sender);
        _grantRole(DEFAULT_ADMIN_ROLE, sender);

        _setRoleAdmin(MINTER_ROLE, OPERATOR_ROLE);

        _mint(sender, 69_400_000 * 10**decimals());
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address to_, uint256 amount_) external onlyRole(MINTER_ROLE) {
        _mint(to_, amount_ * 10**decimals());
    }

    function updateTreasury(ITreasury treasury_)
        external
        override
        onlyRole(OPERATOR_ROLE)
    {
        require(address(treasury_) != address(0), "ERC20: ZERO_ADDRESS");
        emit TreasuryUpdated(treasury(), treasury_);
        _updateTreasury(treasury_);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Pausable) {
        ERC20Pausable._beforeTokenTransfer(from, to, amount);
    }
}

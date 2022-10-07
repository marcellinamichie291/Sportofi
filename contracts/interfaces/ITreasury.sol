// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../internal-upgradeable/interfaces/IWithdrawableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface ITreasury is IWithdrawableUpgradeable {
    event PaymentsUpdated();
    event PricesUpdated();
    event PriceUpdated(
        IERC20Upgradeable indexed token,
        uint256 indexed from,
        uint256 indexed to
    );
    event PaymentRemoved(address indexed token);
    event PaymentsRemoved();

    function supportedPayment(IERC20Upgradeable token_)
        external
        view
        returns (bool);

    function withdraw(
        IERC20Upgradeable token_,
        address to_,
        uint256 amount_,
        uint256 deadline_,
        bytes calldata signature_
    ) external;

    function payments() external view returns (address[] memory);

    function updatePayments(IERC20Upgradeable[] calldata tokens_) external;

    function removePayment(address token_) external;
}

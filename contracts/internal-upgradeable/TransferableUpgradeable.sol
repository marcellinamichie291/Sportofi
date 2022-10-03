// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "oz-custom/contracts/oz-upgradeable/proxy/utils/Initializable.sol";
import "oz-custom/contracts/oz-upgradeable/token/ERC20/IERC20Upgradeable.sol";

error Transferable__TransferFailed();
error Transferable__InvalidArguments();

abstract contract TransferableUpgradeable is Initializable {
    function __Transferable_init() internal onlyInitializing {}

    function __Transferable_init_unchained() internal onlyInitializing {}

    function _safeTransferFrom(
        IERC20Upgradeable token_,
        address from_,
        address to_,
        uint256 value_
    ) internal virtual {
        if (value_ == 0 || to_ == address(0))
            revert Transferable__InvalidArguments();
        bool success;
        if (address(token_) == address(0))
            success = __nativeTransfer(to_, value_);
        else {
            assembly {
                let freeMemoryPointer := mload(0x40)

                mstore(
                    freeMemoryPointer,
                    0x23b872dd00000000000000000000000000000000000000000000000000000000
                )
                mstore(add(freeMemoryPointer, 4), from_)
                mstore(add(freeMemoryPointer, 36), to_)
                mstore(add(freeMemoryPointer, 68), value_)

                success := and(
                    or(
                        and(eq(mload(0), 1), gt(returndatasize(), 31)),
                        iszero(returndatasize())
                    ),
                    call(gas(), token_, 0, freeMemoryPointer, 100, 0, 32)
                )
            }
        }

        if (!success) revert Transferable__TransferFailed();
    }

    function _safeTransfer(
        IERC20Upgradeable token_,
        address to_,
        uint256 value_
    ) internal virtual {
        if (value_ == 0 || to_ == address(0))
            revert Transferable__InvalidArguments();

        bool success;
        if (address(token_) == address(0))
            success = __nativeTransfer(to_, value_);
        else {
            assembly {
                // Get a pointer to some free memory.
                let freeMemoryPointer := mload(0x40)

                // Write the abi-encoded calldata into memory, beginning with the function selector.
                mstore(
                    freeMemoryPointer,
                    0xa9059cbb00000000000000000000000000000000000000000000000000000000
                )
                mstore(add(freeMemoryPointer, 4), to_) // Append the "to" argument.
                mstore(add(freeMemoryPointer, 36), value_) // Append the "amount" argument.

                success := and(
                    or(
                        and(eq(mload(0), 1), gt(returndatasize(), 31)),
                        iszero(returndatasize())
                    ),
                    call(gas(), token_, 0, freeMemoryPointer, 68, 0, 32)
                )
            }
        }

        if (!success) revert Transferable__TransferFailed();
    }

    function _safeNativeTransfer(address to_, uint256 amount_)
        internal
        virtual
    {
        if (!__nativeTransfer(to_, amount_))
            revert Transferable__TransferFailed();
    }

    function __nativeTransfer(address to_, uint256 amount_)
        private
        returns (bool success)
    {
        assembly {
            success := call(gas(), to_, amount_, 0, 0, 0, 0)
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

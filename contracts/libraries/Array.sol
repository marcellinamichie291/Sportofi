// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./BitMap256.sol";

library Array {
    using BitMap256 for uint256;

    // 100 record ~= 60k gas
    function buildSet(uint256[] memory arr_)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256 length = arr_.length;
        {
            uint256 val;
            uint256 bitmap;
            for (uint256 i; i < length; ) {
                unchecked {
                    val = arr_[i];
                    while (length > i && bitmap.get(val)) val = arr_[--length];
                    bitmap = bitmap.set(arr_[i] = val);
                    ++i;
                }
            }
        }
        assembly {
            mstore(arr_, length)
        }
        return arr_;
    }
}

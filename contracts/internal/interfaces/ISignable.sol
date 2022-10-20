// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ISignable {
    function nonces(address sender_) external view returns (uint256);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

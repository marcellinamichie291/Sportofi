// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/Create2.sol";

import "../libraries/Create3.sol";

abstract contract DeterministicDeployer {
    event Deployed(
        address indexed instance,
        bytes32 indexed salt,
        bytes32 indexed bytecodeHash,
        string factory
    );

    function _deploy(
        uint256 amount_,
        bytes32 salt_,
        bytes memory bytecode_
    ) internal virtual;
}

abstract contract Create2Deployer is DeterministicDeployer {
    function instanceOf(bytes32 salt_, bytes32 bytecodeHash_)
        external
        view
        returns (address instance, bool isDeployed)
    {
        instance = Create2.computeAddress(salt_, bytecodeHash_);
        isDeployed = instance.code.length != 0;
    }

    function _deploy(
        uint256 amount_,
        bytes32 salt_,
        bytes memory bytecode_
    ) internal override {
        address instance = Create2.deploy(amount_, salt_, bytecode_);

        emit Deployed(
            instance,
            salt_,
            instance.codehash,
            type(Create2Deployer).name
        );
    }
}

abstract contract Create3Deployer is DeterministicDeployer {
    function instanceOf(bytes32 salt_)
        external
        view
        returns (address instance, bool isDeployed)
    {
        instance = Create3.getDeployed(salt_);
        isDeployed = instance.code.length != 0;
    }

    function _deploy(
        uint256 amount_,
        bytes32 salt_,
        bytes memory bytecode_
    ) internal override {
        address instance = Create3.deploy(salt_, bytecode_, amount_);

        emit Deployed(
            instance,
            salt_,
            instance.codehash,
            type(Create3Deployer).name
        );
    }
}

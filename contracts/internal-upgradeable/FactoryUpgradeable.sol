// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/BitMapsUpgradeable.sol";

import "./interfaces/IFactoryUpgradeable.sol";

import "../libraries/CREATE3.sol";
import "../libraries/Bytes32Address.sol";

abstract contract FactoryUpgradeable is IFactoryUpgradeable, Initializable {
    using Bytes32Address for address;
    using Bytes32Address for bytes32;
    using BitMapsUpgradeable for BitMapsUpgradeable.BitMap;

    BitMapsUpgradeable.BitMap private __deployed;

    function __Factory_init() internal onlyInitializing {}

    function __Factory_init_unchained() internal onlyInitializing {}

    function deployed(address addr_) public view returns (bool) {
        return __deployed.get(addr_.fillFirst96Bits());
    }

    function instanceOf(bytes32 salt_)
        external
        view
        returns (address instance, bool isDeployed)
    {
        instance = CREATE3.getDeployed(salt_);
        isDeployed = deployed(instance);
    }

    function _deploy(
        uint256 amount_,
        bytes32 salt_,
        bytes memory creationCode_
    ) internal returns (address deployed_, address proxy) {
        (deployed_, proxy) = CREATE3.deploy(salt_, creationCode_, amount_);

        emit Deployed(deployed_, salt_, 0, 3);
    }

    uint256[49] private __gap;
}

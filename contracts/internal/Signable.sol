// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

import "./interfaces/ISignable.sol";

import "../libraries/Bytes32Address.sol";

abstract contract Signable is EIP712, ISignable {
    using ECDSA for bytes32;
    using Bytes32Address for address;

    mapping(bytes32 => uint256) internal _nonces;

    constructor(string memory name_, string memory version_)
        payable
        EIP712(name_, version_)
    {}

    function nonces(address sender_) external view returns (uint256) {
        return _nonce(sender_);
    }

    function _verify(
        address verifier_,
        bytes32 structHash_,
        bytes calldata signature_
    ) internal view virtual {
        _checkVerifier(verifier_, structHash_, signature_);
    }

    function _checkVerifier(
        address verifier_,
        bytes32 structHash_,
        bytes calldata signature_
    ) internal view virtual {
        require(
            _recoverSigner(structHash_, signature_) == verifier_,
            "SIGNABLE: INVALID_SIGNATURE"
        );
    }

    function _recoverSigner(bytes32 structHash_, bytes calldata signature_)
        internal
        view
        returns (address)
    {
        return _hashTypedDataV4(structHash_).recover(signature_);
    }

    function _useNonce(address sender_) internal virtual returns (uint256) {
        unchecked {
            return _nonces[sender_.fillLast12Bytes()]++;
        }
    }

    function _nonce(address sender_) internal view virtual returns (uint256) {
        return _nonces[sender_.fillLast12Bytes()];
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./internal-upgradeable/SignableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./internal-upgradeable/BaseUpgradeable.sol";
import "./internal-upgradeable/ProxyCheckerUpgradeable.sol";
import "./internal-upgradeable/WithdrawableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

import "./interfaces/ITreasury.sol";

contract TreasuryUpgradeable is
    ITreasury,
    BaseUpgradeable,
    SignableUpgradeable,
    ProxyCheckerUpgradeable,
    WithdrawableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using Bytes32Address for address;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    ///@dev value is equal to keccak256("Treasury_v2")
    bytes32 public constant VERSION =
        0x48c79cba00677850a648b537b2558198a45e7f81d7643207ace134fa238f149f;

    ///@dev value is equal to keccak256("Permit(address token,address to,uint256 amount,uint256 nonce,uint256 deadline)")
    bytes32 private constant _PERMIT_TYPE_HASH =
        0xe18b1420a8866bed17ce7f2984deaf7e4fe41b94563dd0768b8376b6bdca6b64;

    EnumerableSetUpgradeable.AddressSet private _payments;

    function init(IGovernance governance_) external initializer {
        __Base_init(governance_, 0);
        __ReentrancyGuard_init();
        __EIP712_init(type(TreasuryUpgradeable).name, "2");
    }

    function withdraw(
        IERC20Upgradeable token_,
        address to_,
        uint256 amount_
    )
        external
        override(IWithdrawableUpgradeable, WithdrawableUpgradeable)
        onlyRole(Roles.TREASURER_ROLE)
    {
        if (supportedPayment(token_)) {
            _safeTransfer(token_, to_, amount_);
            emit Withdrawn(token_, to_, amount_);
        }
    }

    function withdraw(
        IERC20Upgradeable token_,
        address to_,
        uint256 amount_,
        address signer_,
        uint256 deadline_,
        bytes calldata signature_
    ) external nonReentrant whenNotPaused {
        _onlyEOA(to_);
        _checkBlacklist(to_);
        _checkRole(Roles.SIGNER_ROLE, signer_);

        // if (block.timestamp > deadline_) revert Treasury__Expired();
        require(block.timestamp <= deadline_, "Expired Time");
        _verify(
            _msgSender(),
            signer_,
            keccak256(
                abi.encode(
                    _PERMIT_TYPE_HASH,
                    token_,
                    to_,
                    _useNonce(to_),
                    deadline_
                )
            ),
            signature_
        );

        _safeTransfer(token_, to_, amount_);

        emit Withdrawn(token_, to_, amount_);
    }

    function updatePayments(IERC20Upgradeable[] calldata tokens_)
        external
        whenPaused
        onlyRole(Roles.TREASURER_ROLE)
    {
        address[] memory tokens;
        {
            IERC20Upgradeable[] memory _token = tokens_;
            assembly {
                tokens := _token
            }
        }
        uint256 length = tokens.length;
        for (uint256 i; i < length; ) {
            _payments.add(tokens[i]);
            unchecked {
                ++i;
            }
        }

        emit PaymentsUpdated();
    }

    function removePayment(address token_)
        external
        whenPaused
        onlyRole(Roles.TREASURER_ROLE)
    {
        if (_payments.remove(token_)) emit PaymentRemoved(token_);
    }

    function payments() external view returns (address[] memory) {
        return _payments.values();
    }

    function supportedPayment(IERC20Upgradeable token_)
        public
        view
        override
        returns (bool)
    {
        return _payments.contains(address(token_));
    }
}

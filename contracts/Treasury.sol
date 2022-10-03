// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "oz-custom/contracts/internal-upgradeable/SignableUpgradeable.sol";
import "oz-custom/contracts/oz-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./internal-upgradeable/BaseUpgradeable.sol";
import "./internal-upgradeable/ProxyCheckerUpgradeable.sol";
import "./internal-upgradeable/WithdrawableUpgradeable.sol";

import "oz-custom/contracts/libraries/EnumerableSetV2.sol";

import "./interfaces/ITreasury.sol";

contract TreasuryUpgradeable is
    ITreasuryV2,
    BaseUpgradeable,
    SignableUpgradeable,
    ProxyCheckerUpgradeable,
    WithdrawableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using Bytes32Address for address;
    using EnumerableSetV2 for EnumerableSetV2.AddressSet;

    ///@dev value is equal to keccak256("Treasury_v2")
    bytes32 public constant VERSION =
        0x48c79cba00677850a648b537b2558198a45e7f81d7643207ace134fa238f149f;

    ///@dev value is equal to keccak256("Permit(address token,address to,uint256 amount,uint256 nonce,uint256 deadline)")
    bytes32 private constant _PERMIT_TYPE_HASH =
        0xe18b1420a8866bed17ce7f2984deaf7e4fe41b94563dd0768b8376b6bdca6b64;

    mapping(bytes32 => uint256) public priceOf;
    EnumerableSetV2.AddressSet private _payments;

    function init(IGovernanceV2 governance_) external initializer {
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

    function updatePrice(IERC20Upgradeable token_, uint256 price_)
        external
        whenPaused
        onlyRole(Roles.TREASURER_ROLE)
    {
        uint256 price;
        if ((price = priceOf[address(token_).fillLast12Bytes()]) != price_) {
            assembly {
                mstore(0x00, token_)
                mstore(0x20, priceOf.slot)
                sstore(keccak256(0x00, 0x40), price_)
            }
        }
        emit PriceUpdated(token_, price, price_);
    }

    function updatePrices(
        address[] calldata tokens_,
        uint256[] calldata prices_
    ) external whenPaused onlyRole(Roles.TREASURER_ROLE) {
        uint256 length = tokens_.length;
        // if (length != prices_.length) revert Treasury__LengthMismatch();
        require (length == prices_.length, "Length mistmatch"); 
        bytes32[] memory tokens;
        {
            address[] memory _tokens;
            assembly {
                tokens := _tokens
            }
        }
        for (uint256 i; i < length; ) {
            priceOf[tokens[i]] = prices_[i];
            unchecked {
                ++i;
            }
        }
        emit PricesUpdated();
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
        _payments.add(tokens);
        emit PaymentsUpdated();
    }

    function resetPayments()
        external
        whenPaused
        onlyRole(Roles.TREASURER_ROLE)
    {
        _payments.remove();
        emit PaymentsRemoved();
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

    function validPayment(address token_) external view returns (bool) {
        return priceOf[token_.fillLast12Bytes()] != 0;
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

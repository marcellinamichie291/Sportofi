// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./interfaces/IReferralUpgradeable.sol";

import "../libraries/FixedPointMathLib.sol";

abstract contract ReferralUpgradeable is Initializable, IReferralUpgradeable {
    using FixedPointMathLib for uint256;

    uint256 private __maxDepth;
    uint16[] public levelBonusRates;

    mapping(address => uint256) public levels;
    mapping(address => uint256) public bonuses;
    mapping(address => address) public referrals;

    function __Referral_init(
        uint256 maxDepth_,
        uint16[] calldata levelBonusRates_
    ) internal onlyInitializing {
        uint256 length = levelBonusRates_.length;
        require(maxDepth_ == length, "REFERRAL: LENGTH_MISMATCH");

        uint256 sum;
        for (uint256 i; i < length; ) {
            unchecked {
                sum += levelBonusRates_[i];
                ++i;
            }
        }

        require(sum == _denominator(), "REFERALL: INVALID_ARGUMENTS");

        __maxDepth = maxDepth_;
        levelBonusRates = levelBonusRates_;
    }

    function __Referral_init_unchained() internal onlyInitializing {}

    function addReferrer(address referrer_, address referree_) external virtual;

    function _addReferrer(address referrer_, address referree_) internal {
        require(
            referrals[referree_] == address(0),
            "REFERRAL: REFERRER_EXISTED"
        );

        address referrer = referrer_;
        while (referrer != address(0)) {
            require(referrer != referree_, "REFERRAL: CIRCULAR_REF_UNALLOWED");

            unchecked {
                ++levels[referrer];
            }
            referrer = referrals[referrer];
        }

        referrals[referree_] = referrer_;

        emit ReferrerAdded(referree_, referrer_);
    }

    function _updateReferrerBonus(address referree_, uint256 amount_) internal {
        uint256 maxDepth = __maxDepth;
        uint16[] memory _levelBonusRates = levelBonusRates;
        for (uint256 i; i < maxDepth; ) {
            unchecked {
                bonuses[referree_] += amount_.mulDivDown(
                    _levelBonusRates[i],
                    _denominator()
                );
                ++i;
            }
        }
    }

    function _denominator() internal pure virtual returns (uint256) {
        return 10_000;
    }

    uint256[45] private __gap;
}

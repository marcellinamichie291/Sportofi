// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IReferralUpgradeable {
    event ReferrerAdded(address indexed referree, address indexed referrer);

    function addReferrer(address referrer_, address referree_) external;
}

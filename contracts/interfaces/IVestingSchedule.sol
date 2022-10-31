// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IVestingSchedule {
    struct Schedule {
        uint96 total;
        uint96 released;
    }

    event Released(address indexed beneficiary, uint256 indexed amount);
    event NewSchedule(address indexed beneficiary, uint256 indexed total);
    event BatchSchedules(
        address[] indexed beneficiaries,
        uint256[] indexed totals
    );

    function createBatchSchedules(
        address[] calldata beneficiaries_,
        uint256[] calldata amounts_
    ) external;

    function createSchedule(address beneficiary_, uint256 amount_) external;

    function withdraw(uint256 amount_) external;

    function release(address beneficiary_) external;

    function withdrawableAmount() external view returns (uint256);

    function releaseableAmount(address beneficiary_)
        external
        view
        returns (uint256);
}

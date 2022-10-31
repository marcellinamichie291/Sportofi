// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./internal/Base.sol";
import "./internal/ProxyChecker.sol";
import "./internal/FundForwarder.sol";

import "./interfaces/IVestingSchedule.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./libraries/FixedPointMathLib.sol";

contract VestingSchedule is
    Base,
    Context,
    ProxyChecker,
    FundForwarder,
    ReentrancyGuard,
    IVestingSchedule
{
    using FixedPointMathLib for uint256;

    uint256 public constant PERCENTAGE_FRACTION = 10_000;

    uint256 public immutable start;
    uint256 public immutable tgeTime;
    uint256 public immutable duration;
    uint256 public immutable tgePercent;
    uint256 public immutable slidePeriod;
    uint256 public immutable slidePercent;
    IERC20 public immutable vestingToken;

    uint256 public vestingTotal;
    mapping(address => Schedule) public schedules;

    constructor(
        uint256 start_,
        uint256 cliff_,
        uint256 duration_,
        uint256 tgePercent_,
        uint256 slidePeriod_,
        IERC20 vestingToken_,
        ITreasury treasury_,
        IAuthority authority_
    ) payable Base(authority_, 0) FundForwarder(treasury_) {
        start = start_;
        tgeTime = start_ + cliff_;
        duration = duration_;
        tgePercent = tgePercent_;
        slidePeriod = slidePeriod_;
        slidePercent =
            (PERCENTAGE_FRACTION - tgePercent) /
            ((duration_ - cliff_) / slidePeriod_);

        require(address(vestingToken_) != address(0), "VESTING: ZERO_ADDRESS");
        vestingToken = vestingToken_;
    }

    function createBatchSchedules(
        address[] calldata beneficiaries_,
        uint256[] calldata amounts_
    ) external onlyRole(Roles.OPERATOR_ROLE) {
        uint256 length = beneficiaries_.length;
        require(length == amounts_.length, "VESTING: LENGTH_MISMATCH");

        uint256 total;
        Schedule memory schedule;
        for (uint256 i; i < length; ) {
            schedule.total = uint96(amounts_[i]);
            schedules[beneficiaries_[i]] = schedule;
            unchecked {
                total += amounts_[i];
                ++i;
            }
        }

        require(total <= withdrawableAmount(), "VESTING: LIMIT_EXCEEDED");

        vestingTotal += total;

        emit BatchSchedules(beneficiaries_, amounts_);
    }

    function createSchedule(address beneficiary_, uint256 amount_)
        external
        onlyRole(Roles.OPERATOR_ROLE)
    {
        require(amount_ <= withdrawableAmount(), "VESTING: LIMIT_EXCEEDED");

        vestingTotal += amount_;
        schedules[beneficiary_] = Schedule(uint96(amount_), 0);

        emit NewSchedule(beneficiary_, amount_);
    }

    function withdraw(uint256 amount_) external onlyRole(Roles.OPERATOR_ROLE) {
        _safeTransfer(vestingToken, _msgSender(), amount_);
    }

    function release(address beneficiary_) external whenNotPaused nonReentrant {
        require(__release(beneficiary_), "VESTING: CANNOT_RELEASE");
    }

    function updateTreasury(ITreasury treasury_) external override {
        require(address(treasury_) != address(0), "VESTING: ZERO_ADDRESS");

        _updateTreasury(treasury_);

        emit TreasuryUpdated(treasury(), treasury_);
    }

    function withdrawableAmount() public view returns (uint256) {
        return vestingToken.balanceOf(address(this)) - vestingTotal;
    }

    function releaseableAmount(address beneficiary_)
        external
        view
        returns (uint256)
    {
        Schedule memory schedule = schedules[beneficiary_];
        return __releasableAmount(schedule);
    }

    function __release(address beneficiary_) private returns (bool) {
        Schedule memory schedule = schedules[beneficiary_];

        address user = _msgSender();
        _checkBlacklist(user);
        _onlyEOA(user);

        require(
            user == beneficiary_ || _hasRole(Roles.OPERATOR_ROLE, user),
            "VESTING: UNAUTHORIZED"
        );

        uint256 vestedAmt = __releasableAmount(schedule);
        if (vestedAmt == 0) return false;

        schedule.released += uint96(vestedAmt);

        vestingTotal -= vestedAmt;
        schedules[beneficiary_] = schedule;

        _safeTransfer(vestingToken, beneficiary_, vestedAmt);

        emit Released(beneficiary_, vestedAmt);

        return true;
    }

    function __releasableAmount(Schedule memory schedule_)
        private
        view
        returns (uint256)
    {
        uint256 _tgeTime = tgeTime;
        if (_tgeTime > block.timestamp) return 0;

        if (block.timestamp >= start + duration)
            return schedule_.total - schedule_.released;

        uint256 totalPercent = tgePercent +
            ((block.timestamp - _tgeTime) / slidePeriod) *
            slidePercent;

        return
            uint256(schedule_.total).mulDivDown(
                totalPercent,
                PERCENTAGE_FRACTION - schedule_.released
            );
    }
}

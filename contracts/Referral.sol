// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// A -> B -> C -> D -> E
// A    0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
// B    0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
// C    0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db
// D    0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
// E    0x617F2E2fD72FD9D5503197092aC168c91465E7f2

// A -> F -> G -> H
// F    0x17F6AD8Ef982297579C203069C1DbfFE4348c372
// G    0x5c6B0f7Bf3E7ce046039Bd8FABdfD3f9F5021678
// H    0x03C6FcED478cBbC9a4FAB34eF9f40767739D1Ff7

contract Referral {
    address public owner;

    mapping(address => uint256) public points;
    mapping(address => uint256) public rewards;
    mapping(address => address) public referrals;

    uint256 public constant MAX_DEPTH = 3;
    uint256 public constant WITHDRAW_THRESHOLD = 1 ether;
    uint256 public constant PERCENTAGE_FRACTION = 10_000;

    modifier onlyOwner() {
        require(owner == msg.sender, "UNAUTHORIZED");
        _;
    }

    constructor() payable {
        owner = msg.sender;
    }

    function addRefferal(address referrer_, address referree_)
        external
        onlyOwner
    {
        if (referrals[referree_] == address(0)) {
            referrals[referree_] = referrer_;
            updateRefPoint(referree_, 1);
        }
    }

    function updateRefPoint(address account, uint256 depth) internal {
        if (depth > MAX_DEPTH) return;

        address referral = referrals[account];
        if (referral == address(0)) return;

        points[referral] += 1;
        updateRefPoint(referral, depth + 1);
    }

    function rewardUser(address user) external payable onlyOwner {
        uint256 rewardAmt = msg.value;
        //  user receive 95% reward
        uint256 userReceived = (rewardAmt * 9_500) / PERCENTAGE_FRACTION;
        rewards[user] += userReceived;
        bonusReward(referrals[user], rewardAmt - userReceived);
    }

    function bonusReward(address account, uint256 reward) internal {
        uint256 received = (reward * percentageOf(points[account])) /
            PERCENTAGE_FRACTION;
        if (received == 0) return;

        rewards[account] += received;
        bonusReward(referrals[account], reward);
    }

    function percentageOf(uint256 point) internal pure returns (uint256) {
        if (point >= 3) return 5_000; //  50%
        if (point >= 2) return 3_000; //  30%
        if (point >= 1) return 2_000; //  20%

        return 0;
    }

    function withdraw() external {
        uint256 amount = rewards[msg.sender];
        require(amount >= WITHDRAW_THRESHOLD, "TOO_SMALL");

        /// @dev prevent reentrancy attacks
        delete rewards[msg.sender];
        msg.sender.call{value: amount};
    }
}

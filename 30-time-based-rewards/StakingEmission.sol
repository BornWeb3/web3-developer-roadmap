// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface MintableERC20 is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract StakingEmission {
    using SafeERC20 for IERC20;

    uint256 private constant ACC_PRECISION = 1e18;

    IERC20 public immutable stakingToken;
    MintableERC20 public immutable rewardToken;

    address public owner;

    uint256 public totalStaked;
    uint256 public rewardPerShare;
    uint256 public lastUpdateTime;
    uint256 public rewardRate;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public rewardDebt;

    event PoolUpdated(
        uint256 indexed timestamp,
        uint256 timePassed,
        uint256 emittedReward,
        uint256 rewardPerShare
    );
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 previousRate, uint256 newRate);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    constructor(
        address _stakingToken,
        address _rewardToken,
        address _owner,
        uint256 _initialRewardRate
    ) {
        require(_stakingToken != address(0), "ZERO_STAKING_TOKEN");
        require(_rewardToken != address(0), "ZERO_REWARD_TOKEN");
        require(_owner != address(0), "ZERO_OWNER");

        stakingToken = IERC20(_stakingToken);
        rewardToken = MintableERC20(_rewardToken);
        owner = _owner;
        rewardRate = _initialRewardRate;
        lastUpdateTime = block.timestamp;

        emit OwnershipTransferred(address(0), _owner);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ZERO_OWNER");

        address previousOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function updatePool() public {
        uint256 currentTime = block.timestamp;
        if (currentTime <= lastUpdateTime) {
            return;
        }

        uint256 timePassed = currentTime - lastUpdateTime;

        if (totalStaked == 0) {
            lastUpdateTime = currentTime;
            emit PoolUpdated(currentTime, timePassed, 0, rewardPerShare);
            return;
        }

        uint256 reward = timePassed * rewardRate;
        rewardPerShare += (reward * ACC_PRECISION) / totalStaked;
        lastUpdateTime = currentTime;

        emit PoolUpdated(currentTime, timePassed, reward, rewardPerShare);
    }

    function setRewardRate(uint256 newRewardRate) external onlyOwner {
        updatePool();

        uint256 previousRate = rewardRate;
        rewardRate = newRewardRate;

        emit RewardRateUpdated(previousRate, newRewardRate);
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "ZERO_AMOUNT");

        updatePool();
        _claimPending(msg.sender);

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        balances[msg.sender] += amount;
        totalStaked += amount;
        rewardDebt[msg.sender] = (balances[msg.sender] * rewardPerShare) / ACC_PRECISION;

        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "ZERO_AMOUNT");
        require(balances[msg.sender] >= amount, "INSUFFICIENT_BALANCE");

        updatePool();
        _claimPending(msg.sender);

        balances[msg.sender] -= amount;
        totalStaked -= amount;
        rewardDebt[msg.sender] = (balances[msg.sender] * rewardPerShare) / ACC_PRECISION;

        stakingToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    function claim() external {
        updatePool();

        uint256 claimed = _claimPending(msg.sender);
        rewardDebt[msg.sender] = (balances[msg.sender] * rewardPerShare) / ACC_PRECISION;

        emit Claimed(msg.sender, claimed);
    }

    function pendingRewards(address user) external view returns (uint256) {
        uint256 currentRewardPerShare = rewardPerShare;

        if (block.timestamp > lastUpdateTime && totalStaked > 0) {
            uint256 timePassed = block.timestamp - lastUpdateTime;
            uint256 reward = timePassed * rewardRate;
            currentRewardPerShare += (reward * ACC_PRECISION) / totalStaked;
        }

        uint256 accumulated = (balances[user] * currentRewardPerShare) / ACC_PRECISION;
        uint256 debt = rewardDebt[user];

        if (accumulated <= debt) {
            return 0;
        }

        return accumulated - debt;
    }

    function _claimPending(address user) internal returns (uint256 pending) {
        uint256 accumulated = (balances[user] * rewardPerShare) / ACC_PRECISION;
        uint256 debt = rewardDebt[user];

        if (accumulated > debt) {
            pending = accumulated - debt;
            rewardToken.mint(user, pending);
        }
    }
}

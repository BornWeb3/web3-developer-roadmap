// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface MintableERC20 is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract StakingEmissionBug {
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
        stakingToken = IERC20(_stakingToken);
        rewardToken = MintableERC20(_rewardToken);
        owner = _owner;
        rewardRate = _initialRewardRate;
        lastUpdateTime = block.timestamp;
    }

    function updatePool() public {
        uint256 currentTime = block.timestamp;

        if (currentTime <= lastUpdateTime) {
            return;
        }

        uint256 timePassed = currentTime - lastUpdateTime;

        if (totalStaked == 0) {
            lastUpdateTime = currentTime;
            return;
        }

        uint256 reward = timePassed * rewardRate;
        rewardPerShare += (reward * ACC_PRECISION) / totalStaked;

        lastUpdateTime = currentTime;
    }

    function deposit(uint256 amount) external {
        updatePool();

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        balances[msg.sender] += amount;
        totalStaked += amount;

        rewardDebt[msg.sender] =
            (balances[msg.sender] * rewardPerShare) /
            ACC_PRECISION;
    }

    function withdraw(uint256 amount) external {
        updatePool();

        balances[msg.sender] -= amount;
        totalStaked -= amount;

        rewardDebt[msg.sender] =
            (balances[msg.sender] * rewardPerShare) /
            ACC_PRECISION;

        stakingToken.safeTransfer(msg.sender, amount);
    }

    function claim() external {
        updatePool();

        uint256 accumulated = (balances[msg.sender] * rewardPerShare) /
            ACC_PRECISION;

        uint256 pending = accumulated - rewardDebt[msg.sender];

        rewardDebt[msg.sender] = accumulated;

        rewardToken.mint(msg.sender, pending);
    }
}

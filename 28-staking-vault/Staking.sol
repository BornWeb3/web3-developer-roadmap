// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Token} from "./Token.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract Staking is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct StakeInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 lastUpdate;
    }

    Token public token;

    uint256 public rewardRate;
    uint256 public accRewardPerShare;
    uint256 public lastRewardTime;
    uint256 public totalStaked;

    mapping(address => StakeInfo) public stakes;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);

    constructor(address tokenAddress, uint256 _rewardRate) {
        require(tokenAddress != address(0), "ZERO_TOKEN");
        token = Token(tokenAddress);
        rewardRate = _rewardRate;
        lastRewardTime = block.timestamp;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function updatePool() public {
        if (block.timestamp <= lastRewardTime) {
            return;
        }

        if (totalStaked == 0) {
            lastRewardTime = block.timestamp;
            return;
        }

        uint256 timePassed = block.timestamp - lastRewardTime;
        uint256 reward = timePassed * rewardRate;

        accRewardPerShare += (reward * 1e12) / totalStaked;
        lastRewardTime = block.timestamp;
    }

    function pendingReward(address user) public view returns (uint256) {
        StakeInfo memory stake = stakes[user];
        uint256 _accRewardPerShare = accRewardPerShare;

        if (block.timestamp > lastRewardTime && totalStaked != 0) {
            uint256 timePassed = block.timestamp - lastRewardTime;
            uint256 reward = timePassed * rewardRate;
            _accRewardPerShare += (reward * 1e12) / totalStaked;
        }

        return (stake.amount * _accRewardPerShare) / 1e12 - stake.rewardDebt;
    }

    function stake(uint256 amount) external {
        require(amount > 0, "ZERO_AMOUNT");

        StakeInfo storage user = stakes[msg.sender];

        updatePool();

        if (user.amount > 0) {
            uint256 pending = (user.amount * accRewardPerShare) /
                1e12 -
                user.rewardDebt;

            if (pending > 0) {
                token.mint(msg.sender, pending);
                emit Claimed(msg.sender, pending);
            }
        }

        token.transferFrom(msg.sender, address(this), amount);

        user.amount += amount;
        user.rewardDebt = (user.amount * accRewardPerShare) / 1e12;
        user.lastUpdate = block.timestamp;

        totalStaked += amount;

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        StakeInfo storage user = stakes[msg.sender];
        require(user.amount >= amount, "INSUFFICIENT");

        updatePool();

        uint256 pending = (user.amount * accRewardPerShare) /
            1e12 -
            user.rewardDebt;

        if (pending > 0) {
            token.mint(msg.sender, pending);
            emit Claimed(msg.sender, pending);
        }

        user.amount -= amount;
        user.rewardDebt = (user.amount * accRewardPerShare) / 1e12;

        totalStaked -= amount;

        token.transfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    function claim() external {
        StakeInfo storage user = stakes[msg.sender];

        updatePool();

        uint256 pending = (user.amount * accRewardPerShare) /
            1e12 -
            user.rewardDebt;

        require(pending > 0, "NOTHING_TO_CLAIM");

        token.mint(msg.sender, pending);

        user.rewardDebt = (user.amount * accRewardPerShare) / 1e12;

        emit Claimed(msg.sender, pending);
    }

    function setRewardRate(uint256 _rewardRate)
        external
        onlyRole(ADMIN_ROLE)
    {
        updatePool();
        rewardRate = _rewardRate;
    }
}

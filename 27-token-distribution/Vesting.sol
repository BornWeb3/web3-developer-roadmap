// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Token} from "./Token.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract Vesting is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct VestingSchedule {
        address beneficiary;
        uint256 totalAmount;
        uint256 startTime;
        uint256 cliffTime;
        uint256 durationTime;
        uint256 claimed;
        bool revoked;
    }

    Token public token;
    mapping(bytes32 => VestingSchedule) public schedules;
    uint256 public scheduleCount;

    event VestingCreated(
        bytes32 indexed scheduleId,
        address indexed beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffTime,
        uint256 durationTime
    );

    event TokensClaimed(
        bytes32 indexed scheduleId,
        address indexed beneficiary,
        uint256 amount
    );

    event VestingRevoked(bytes32 indexed scheduleId);

    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "ZERO_TOKEN");
        token = Token(tokenAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function createVesting(
        address beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffTime,
        uint256 durationTime
    ) external onlyRole(ADMIN_ROLE) returns (bytes32 scheduleId) {
        require(beneficiary != address(0), "ZERO_BENEFICIARY");
        require(totalAmount > 0, "ZERO_AMOUNT");
        require(durationTime > 0, "ZERO_DURATION");
        require(cliffTime <= durationTime, "CLIFF_GT_DURATION");

        scheduleId = keccak256(abi.encodePacked(beneficiary, scheduleCount++));

        schedules[scheduleId] = VestingSchedule({
            beneficiary: beneficiary,
            totalAmount: totalAmount,
            startTime: startTime,
            cliffTime: cliffTime,
            durationTime: durationTime,
            claimed: 0,
            revoked: false
        });

        emit VestingCreated(
            scheduleId,
            beneficiary,
            totalAmount,
            startTime,
            cliffTime,
            durationTime
        );
    }

    function getVestedAmount(bytes32 scheduleId)
        public
        view
        returns (uint256)
    {
        VestingSchedule memory schedule = schedules[scheduleId];

        if (schedule.revoked) {
            return 0;
        }

        if (block.timestamp < schedule.startTime + schedule.cliffTime) {
            return 0;
        }

        if (block.timestamp >= schedule.startTime + schedule.durationTime) {
            return schedule.totalAmount;
        }

        uint256 elapsed = block.timestamp - schedule.startTime;
        uint256 vested = (schedule.totalAmount * elapsed) /
            schedule.durationTime;

        return vested;
    }

    function getClaimableAmount(bytes32 scheduleId)
        external
        view
        returns (uint256)
    {
        uint256 vested = getVestedAmount(scheduleId);
        uint256 claimed = schedules[scheduleId].claimed;

        if (vested > claimed) {
            return vested - claimed;
        }
        return 0;
    }

    function claim(bytes32 scheduleId) external {
        VestingSchedule storage schedule = schedules[scheduleId];

        require(msg.sender == schedule.beneficiary, "NOT_BENEFICIARY");
        require(!schedule.revoked, "REVOKED");

        uint256 vested = getVestedAmount(scheduleId);
        uint256 claimable = vested - schedule.claimed;

        require(claimable > 0, "NOTHING_TO_CLAIM");

        schedule.claimed = vested;

        token.mint(msg.sender, claimable);

        emit TokensClaimed(scheduleId, msg.sender, claimable);
    }

    function revokeVesting(bytes32 scheduleId)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(!schedules[scheduleId].revoked, "ALREADY_REVOKED");
        schedules[scheduleId].revoked = true;
        emit VestingRevoked(scheduleId);
    }
}

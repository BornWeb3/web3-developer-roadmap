// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Config {
    uint256 public fee = 100;
    uint256 public maxUsers = 1000;
    bool public paused;

    address public immutable timelock;

    event FeeChanged(uint256 oldFee, uint256 newFee);
    event MaxUsersChanged(uint256 oldMax, uint256 newMax);
    event PausedStatusChanged(bool newStatus);

    modifier onlyTimelock() {
        require(msg.sender == timelock, "ONLY_TIMELOCK");
        _;
    }

    constructor(address timelockAddress) {
        require(timelockAddress != address(0), "ZERO_TIMELOCK");
        timelock = timelockAddress;
    }

    function setFee(uint256 newFee) external onlyTimelock {
        require(newFee <= 10000, "FEE_TOO_HIGH");

        uint256 oldFee = fee;
        fee = newFee;

        emit FeeChanged(oldFee, newFee);
    }

    function setMaxUsers(uint256 newMax) external onlyTimelock {
        require(newMax > 0, "ZERO_MAX");

        uint256 oldMax = maxUsers;
        maxUsers = newMax;

        emit MaxUsersChanged(oldMax, newMax);
    }

    function setPaused(bool status) external onlyTimelock {
        paused = status;

        emit PausedStatusChanged(status);
    }

    function getConfig()
        external
        view
        returns (
            uint256 currentFee,
            uint256 currentMaxUsers,
            bool currentPaused
        )
    {
        return (fee, maxUsers, paused);
    }
}

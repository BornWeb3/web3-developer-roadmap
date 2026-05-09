// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IERC20Minimal {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract ProfitSource {
    address public immutable owner;
    IERC20Minimal public immutable rewardToken;

    event ProfitDistributed(
        address indexed recipient,
        uint256 amount
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "ZERO_TOKEN");

        owner = msg.sender;
        rewardToken = IERC20Minimal(tokenAddress);
    }

    function distributeProfit(
        address recipient,
        uint256 amount
    ) external onlyOwner {
        require(recipient != address(0), "ZERO_RECIPIENT");
        require(amount > 0, "ZERO_AMOUNT");

        bool success = rewardToken.transfer(recipient, amount);

        require(success, "TRANSFER_FAILED");

        emit ProfitDistributed(recipient, amount);
    }
}

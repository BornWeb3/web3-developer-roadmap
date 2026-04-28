// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

contract Vault {

    mapping(address => uint256) public balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    error ZeroAmount();
    error InsufficientBalance();

    function deposit() external payable {
        if (msg.value == 0) {
            revert ZeroAmount();
        }

        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) {
            revert ZeroAmount();
        }

        uint256 userBalance = balances[msg.sender];
        if (userBalance < amount) {
            revert InsufficientBalance();
        }

        balances[msg.sender] = userBalance - amount;

        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "ETH_TRANSFER_FAILED");

        emit Withdraw(msg.sender, amount);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

contract Vault {
    address public owner;

    mapping(address => uint256) public balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    error NotOwner();
    error ZeroValue();
    error InsufficientBalance();

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function deposit() external payable {
        if (msg.value == 0) {
            revert ZeroValue();
        }

        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) {
            revert ZeroValue();
        }
        if (balances[msg.sender] < amount) {
            revert InsufficientBalance();
        }

        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);

        emit Withdraw(msg.sender, amount);
    }

    function transferTo(address to, uint256 amount) external {
        if (amount == 0) {
            revert ZeroValue();
        }
        if (balances[msg.sender] < amount) {
            revert InsufficientBalance();
        }

        balances[msg.sender] -= amount;
        balances[to] += amount;

        emit Transfer(msg.sender, to, amount);
    }

    function getBalance(address user) external view returns (uint256) {
        return balances[user];
    }
}

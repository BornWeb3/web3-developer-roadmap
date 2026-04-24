// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Vault {

    address public immutable owner;

    uint256 public totalDeposited;
    uint256 public totalWithdrawn;

    event Deposited(address indexed from, uint256 msgValue, uint256 contractBalance);
    event Received(address indexed from, uint256 msgValue, uint256 contractBalance);
    event FallbackReceived(address indexed from, uint256 msgValue, bytes data, uint256 contractBalance);
    event Withdrawn(address indexed byOwner, uint256 amount, uint256 contractBalanceAfter);

    error NotOwner();
    error ZeroValue();
    error InsufficientContractBalance();
    error TransferFailed();

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    function deposit() external payable {
        if (msg.value == 0) {
            revert ZeroValue();
        }

        totalDeposited += msg.value;
        emit Deposited(msg.sender, msg.value, address(this).balance);
    }

    receive() external payable {
        if (msg.value == 0) {
            revert ZeroValue();
        }

        totalDeposited += msg.value;
        emit Received(msg.sender, msg.value, address(this).balance);
    }

    fallback() external payable {
        if (msg.value == 0) {
            revert ZeroValue();
        }

        totalDeposited += msg.value;
        emit FallbackReceived(msg.sender, msg.value, msg.data, address(this).balance);
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function withdraw(uint256 amount) external onlyOwner {
        uint256 currentBalance = address(this).balance;

        if (amount == 0 || amount > currentBalance) {
            revert InsufficientContractBalance();
        }

        totalWithdrawn += amount;

        (bool sent,) = payable(owner).call{value: amount}("");
        if (!sent) {
            revert TransferFailed();
        }

        emit Withdrawn(msg.sender, amount, address(this).balance);
    }
}

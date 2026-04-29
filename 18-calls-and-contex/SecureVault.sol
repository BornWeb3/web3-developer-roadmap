// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract SecureVault {
    mapping(address => uint256) public balances;

    address public immutable owner;

    bool private locked;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    modifier nonReentrant() {
        require(!locked, "REENTRANCY_GUARD");
        locked = true;
        _;
        locked = false;
    }

    function deposit() external payable {
        require(msg.value > 0, "ZERO_VALUE");
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "ZERO_AMOUNT");
        require(balances[msg.sender] >= amount, "INSUFFICIENT_BALANCE");

        balances[msg.sender] -= amount;

        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "ETH_SEND_FAILED");

        emit Withdraw(msg.sender, amount);
    }

    function emergencyWithdraw(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "ZERO_RECIPIENT");
        require(amount <= address(this).balance, "INSUFFICIENT_VAULT_BALANCE");

        (bool success,) = payable(to).call{value: amount}("");
        require(success, "EMERGENCY_SEND_FAILED");
    }

    function vaultBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

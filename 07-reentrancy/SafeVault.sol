// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract SafeVault {
    
    mapping(address => uint256) public balances;
    address public immutable owner;
    bool public withdrawalsPaused;

    event Deposited(address indexed user, uint256 amount, uint256 contractBalance);
    event Withdrawn(address indexed user, uint256 amount, uint256 contractBalanceAfter);
    event WithdrawalsPaused(bool paused);

    constructor() {
        owner = msg.sender;
    }

    function deposit() external payable {
        require(msg.value > 0, "ZERO_VALUE");

        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value, address(this).balance);
    }

    function withdraw() external {
        require(!withdrawalsPaused, "WITHDRAWALS_PAUSED");

        uint256 amount = balances[msg.sender];
        require(amount > 0, "NO_BALANCE");

        balances[msg.sender] = 0;

        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "ETH_SEND_FAILED");

        emit Withdrawn(msg.sender, amount, address(this).balance);
    }

    function pauseWithdrawals(bool paused) external {
        require(msg.sender == owner, "NOT_OWNER");
        withdrawalsPaused = paused;
        emit WithdrawalsPaused(paused);
    }

    function vaultBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

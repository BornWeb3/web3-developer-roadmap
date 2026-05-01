// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Vault {
    address public owner;

    constructor(address _owner) {
        owner = _owner;
    }
}

contract Factory {
    Vault[] public vaults;

    function createVault() external {
        Vault vault = new Vault(msg.sender);
        vaults.push(vault);
    }

    function getVaults() external view returns (Vault[] memory) {
        return vaults;
    }
}

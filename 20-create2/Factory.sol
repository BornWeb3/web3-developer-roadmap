// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Vault.sol";

contract Factory {
    address[] public vaults;

    mapping(address => address) public userVault;

    event VaultCreated(address indexed owner, address indexed vault);

    error VaultAlreadyExists();

    function createVault() external returns (address vault) {
        if (userVault[msg.sender] != address(0)) {
            revert VaultAlreadyExists();
        }

        Vault newVault = new Vault(msg.sender);
        vault = address(newVault);

        vaults.push(vault);
        userVault[msg.sender] = vault;

        emit VaultCreated(msg.sender, vault);
    }

    function getVaults() external view returns (address[] memory) {
        return vaults;
    }

    function getUserVault(address user) external view returns (address) {
        return userVault[user];
    }
}

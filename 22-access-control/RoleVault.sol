// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract RoleVault {
    mapping(address => bool) public isAdmin;
    bool private initialized;

    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "NOT_ADMIN");
        _;
    }

    function initialize(address admin) external {
        require(!initialized, "ALREADY_INITIALIZED");
        require(admin != address(0), "ZERO_ADMIN");

        isAdmin[admin] = true;
        initialized = true;
    }

    function addAdmin(address account) external onlyAdmin {
        isAdmin[account] = true;
    }

    function removeAdmin(address account) external onlyAdmin {
        isAdmin[account] = false;
    }

    function withdraw(address payable to, uint256 amount) external onlyAdmin {
        require(address(this).balance >= amount, "INSUFFICIENT_BALANCE");
        to.transfer(amount);
    }

    receive() external payable {}
}

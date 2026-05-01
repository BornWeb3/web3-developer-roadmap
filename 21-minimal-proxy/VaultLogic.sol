// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract VaultLogic {
    address public owner;
    bool private initialized;

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    function initialize(address _owner) external {
        require(!initialized, "ALREADY_INITIALIZED");
        require(_owner != address(0), "ZERO_OWNER");

        owner = _owner;
        initialized = true;
    }

    function withdraw(address payable to, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "INSUFFICIENT_BALANCE");
        to.transfer(amount);
    }

    receive() external payable {}
}

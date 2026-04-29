// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Vault {
    address public owner;

    error NotOwner();

    constructor(address _owner) {
        owner = _owner;
    }

    receive() external payable {}

    function withdraw() external {
        if (msg.sender != owner) {
            revert NotOwner();
        }

        payable(owner).transfer(address(this).balance);
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

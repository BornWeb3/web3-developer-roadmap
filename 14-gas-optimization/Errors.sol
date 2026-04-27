// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Errors {

    error NotOwner(address caller);
    error InvalidValue(uint256 value);

    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function setOwner(address newOwner) external {
        if (msg.sender != owner) {
            revert NotOwner(msg.sender);
        }
        owner = newOwner;
    }

    function setValue(uint256 value) external pure returns (uint256) {
        if (value == 0) {
            revert InvalidValue(value);
        }
        return value;
    }
}

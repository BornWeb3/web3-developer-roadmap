// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract Treasury is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    receive() external payable {}

    function withdraw(address payable to, uint256 amount)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(to != address(0), "ZERO_ADDRESS");
        require(address(this).balance >= amount, "INSUFFICIENT_BALANCE");

        (bool success, ) = to.call{value: amount}("");
        require(success, "TRANSFER_FAILED");
    }
}

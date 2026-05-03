// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Token} from "./Token.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract Airdrop is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    Token public token;
    mapping(address => uint256) public allocations;

    event AllocationSet(address indexed account, uint256 amount);
    event Claimed(address indexed account, uint256 amount);

    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "ZERO_TOKEN");
        token = Token(tokenAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function setAllocations(
        address[] calldata accounts,
        uint256[] calldata amounts
    ) external onlyRole(ADMIN_ROLE) {
        require(accounts.length == amounts.length, "ARRAY_MISMATCH");

        for (uint256 i = 0; i < accounts.length; i++) {
            require(accounts[i] != address(0), "ZERO_ADDRESS");
            allocations[accounts[i]] = amounts[i];
            emit AllocationSet(accounts[i], amounts[i]);
        }
    }

    function claim() external {
        uint256 amount = allocations[msg.sender];
        require(amount > 0, "NO_ALLOCATION");

        allocations[msg.sender] = 0;

        token.mint(msg.sender, amount);

        emit Claimed(msg.sender, amount);
    }
}

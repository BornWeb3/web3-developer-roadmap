// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(
        string memory name_,
        string memory symbol_,
        address initialAdmin,
        uint256 initialSupply
    ) ERC20(name_, symbol_) {
        require(initialAdmin != address(0), "ZERO_ADMIN");

        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(ADMIN_ROLE, initialAdmin);
        _grantRole(MINTER_ROLE, initialAdmin);

        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(MINTER_ROLE, ADMIN_ROLE);

        if (initialSupply > 0) {
            _mint(initialAdmin, initialSupply);
        }
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(to != address(0), "ZERO_TO");
        require(amount > 0, "ZERO_AMOUNT");

        _mint(to, amount);
    }

    function grantMinter(address account) external onlyRole(ADMIN_ROLE) {
        grantRole(MINTER_ROLE, account);
    }

    function revokeMinter(address account) external onlyRole(ADMIN_ROLE) {
        revokeRole(MINTER_ROLE, account);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Lesson26Token} from "./Lesson26Token.sol";

contract EmissionController is AccessControl {

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    Token public immutable token;
    uint256 public emissionPerSecond;
    uint256 public lastMint;

    constructor(
        address admin,
        address tokenAddress,
        uint256 emissionRate
    ) {
        require(admin != address(0), "ZERO_ADMIN");
        require(tokenAddress != address(0), "ZERO_TOKEN");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);

        token = Token(tokenAddress);
        emissionPerSecond = emissionRate;
        lastMint = block.timestamp;
    }

    function setEmissionRate(uint256 newRate) external onlyRole(ADMIN_ROLE) {
        emissionPerSecond = newRate;
    }

    function mint() external {
        uint256 timePassed = block.timestamp - lastMint;
        require(timePassed > 0, "NO_TIME");

        uint256 amount = timePassed * emissionPerSecond;
        lastMint = block.timestamp;

        token.mint(msg.sender, amount);
    }
}

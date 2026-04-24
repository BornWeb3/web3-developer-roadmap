// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Token is ERC20, Ownable, ReentrancyGuard {

    constructor(uint256 initialSupply)
        ERC20("Varathon Lesson 9 Token", "VL9")
        Ownable(msg.sender)
    {
        _mint(msg.sender, initialSupply);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function sendEthNoGuard(address payable to, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "INSUFFICIENT_ETH");

        (bool success, ) = to.call{value: amount}("");
        require(success, "ETH_SEND_FAILED");
    }

    function sendEthWithGuard(address payable to, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        require(address(this).balance >= amount, "INSUFFICIENT_ETH");

        (bool success, ) = to.call{value: amount}("");
        require(success, "ETH_SEND_FAILED");
    }

    receive() external payable {}
}

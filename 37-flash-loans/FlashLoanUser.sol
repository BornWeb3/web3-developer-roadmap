// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFlashLoanPool {
    function flashLoan(uint256 amount, address receiver, bytes calldata data) external;
}

contract FlashLoanUser {
    address public immutable pool;

    constructor(address _pool) {
        require(_pool != address(0), "ZERO_POOL");
        pool = _pool;
    }

    function requestFlashLoan(address token, uint256 amount) external {
        bytes memory data = abi.encode(msg.sender);
        IFlashLoanPool(pool).flashLoan(amount, address(this), data);

        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).transfer(msg.sender, balance);
        }
    }

    function executeOperation(address token, uint256 amount, bytes calldata data) external {
        require(msg.sender == pool, "ONLY_POOL");

        address initiator = abi.decode(data, (address));

        IERC20(token).transfer(pool, amount);
    }
}

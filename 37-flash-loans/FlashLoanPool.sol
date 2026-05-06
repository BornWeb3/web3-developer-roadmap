// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IFlashLoanReceiver {
    function executeOperation(address token, uint256 amount, bytes calldata data) external;
}

contract FlashLoanPool {
    using SafeERC20 for IERC20;

    address public immutable token;

    event LiquidityDeposited(address indexed provider, uint256 amount, uint256 newPoolBalance);
    event FlashLoanExecuted(
        address indexed initiator,
        address indexed receiver,
        uint256 amount,
        uint256 balanceBefore,
        uint256 balanceAfter
    );

    constructor(address _token) {
        require(_token != address(0), "ZERO_TOKEN");
        token = _token;
    }

    function depositLiquidity(uint256 amount) external {
        require(amount > 0, "ZERO_AMOUNT");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit LiquidityDeposited(msg.sender, amount, IERC20(token).balanceOf(address(this)));
    }

    function flashLoan(uint256 amount, address receiver, bytes calldata data) external {
        require(amount > 0, "ZERO_AMOUNT");
        require(receiver != address(0), "ZERO_RECEIVER");

        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        require(balanceBefore >= amount, "INSUFFICIENT_POOL_BALANCE");

        IERC20(token).safeTransfer(receiver, amount);

        IFlashLoanReceiver(receiver).executeOperation(token, amount, data);

        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "FLASH_LOAN_NOT_REPAID");

        emit FlashLoanExecuted(msg.sender, receiver, amount, balanceBefore, balanceAfter);
    }

    function getPoolBalance() external view returns (uint256 poolBalance) {
        poolBalance = IERC20(token).balanceOf(address(this));
    }
}

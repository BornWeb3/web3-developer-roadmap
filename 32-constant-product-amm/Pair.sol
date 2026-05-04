// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Pair {
    using SafeERC20 for IERC20;

    address public immutable token0;
    address public immutable token1;

    uint256 public reserve0;
    uint256 public reserve1;

    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidityBalance;

    event LiquidityAdded(address indexed user, uint256 amount0, uint256 amount1, uint256 liquidityMinted);
    event LiquidityRemoved(address indexed user, uint256 liquidityBurned, uint256 amount0, uint256 amount1);
    event Swapped(address indexed user, address indexed tokenIn, uint256 amountIn, address indexed tokenOut, uint256 amountOut);
    event ReservesUpdated(uint256 reserve0, uint256 reserve1);

    constructor(address _token0, address _token1) {
        require(_token0 != address(0), "ZERO_TOKEN0");
        require(_token1 != address(0), "ZERO_TOKEN1");
        require(_token0 != _token1, "IDENTICAL_TOKENS");

        token0 = _token0;
        token1 = _token1;
    }

    function addLiquidity(uint256 amount0, uint256 amount1) external returns (uint256 liquidity) {
        require(amount0 > 0, "ZERO_AMOUNT0");
        require(amount1 > 0, "ZERO_AMOUNT1");

        if (totalLiquidity == 0) {
            liquidity = amount0 + amount1;
        } else {
            uint256 liquidityFrom0 = (amount0 * totalLiquidity) / reserve0;
            uint256 liquidityFrom1 = (amount1 * totalLiquidity) / reserve1;
            liquidity = liquidityFrom0 < liquidityFrom1 ? liquidityFrom0 : liquidityFrom1;
        }

        require(liquidity > 0, "ZERO_LIQUIDITY");

        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);

        liquidityBalance[msg.sender] += liquidity;
        totalLiquidity += liquidity;

        _updateReserves();
        emit LiquidityAdded(msg.sender, amount0, amount1, liquidity);
    }

    function removeLiquidity(uint256 liquidityAmount)
        external
        returns (uint256 amount0Out, uint256 amount1Out)
    {
        require(liquidityAmount > 0, "ZERO_LIQUIDITY");
        require(liquidityBalance[msg.sender] >= liquidityAmount, "INSUFFICIENT_LIQUIDITY");

        amount0Out = (liquidityAmount * reserve0) / totalLiquidity;
        amount1Out = (liquidityAmount * reserve1) / totalLiquidity;

        require(amount0Out > 0 || amount1Out > 0, "ZERO_WITHDRAW");

        liquidityBalance[msg.sender] -= liquidityAmount;
        totalLiquidity -= liquidityAmount;

        if (amount0Out > 0) {
            IERC20(token0).safeTransfer(msg.sender, amount0Out);
        }
        if (amount1Out > 0) {
            IERC20(token1).safeTransfer(msg.sender, amount1Out);
        }

        _updateReserves();
        emit LiquidityRemoved(msg.sender, liquidityAmount, amount0Out, amount1Out);
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut)
        external
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "ZERO_AMOUNT_IN");
        require(tokenIn == token0 || tokenIn == token1, "INVALID_TOKEN_IN");
        require(reserve0 > 0 && reserve1 > 0, "EMPTY_POOL");

        bool zeroToOne = tokenIn == token0;

        if (zeroToOne) {
            amountOut = _getAmountOut(amountIn, reserve0, reserve1);
            require(amountOut <= reserve1, "INSUFFICIENT_LIQ1");
            require(amountOut >= minAmountOut, "SLIPPAGE");

            IERC20(token0).safeTransferFrom(msg.sender, address(this), amountIn);
            IERC20(token1).safeTransfer(msg.sender, amountOut);

            emit Swapped(msg.sender, token0, amountIn, token1, amountOut);
        } else {
            amountOut = _getAmountOut(amountIn, reserve1, reserve0);
            require(amountOut <= reserve0, "INSUFFICIENT_LIQ0");
            require(amountOut >= minAmountOut, "SLIPPAGE");

            IERC20(token1).safeTransferFrom(msg.sender, address(this), amountIn);
            IERC20(token0).safeTransfer(msg.sender, amountOut);

            emit Swapped(msg.sender, token1, amountIn, token0, amountOut);
        }

        _updateReserves();
    }

    function getAmountOut(address tokenIn, uint256 amountIn) external view returns (uint256 amountOut) {
        require(amountIn > 0, "ZERO_AMOUNT_IN");
        require(tokenIn == token0 || tokenIn == token1, "INVALID_TOKEN_IN");
        require(reserve0 > 0 && reserve1 > 0, "EMPTY_POOL");

        if (tokenIn == token0) {
            amountOut = _getAmountOut(amountIn, reserve0, reserve1);
        } else {
            amountOut = _getAmountOut(amountIn, reserve1, reserve0);
        }
    }

    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
        require(amountOut > 0, "ZERO_AMOUNT_OUT");
    }

    function _updateReserves() internal {
        reserve0 = IERC20(token0).balanceOf(address(this));
        reserve1 = IERC20(token1).balanceOf(address(this));

        emit ReservesUpdated(reserve0, reserve1);
    }

    function getPrice() external view returns (uint256 priceE18) {
        require(reserve0 > 0, "ZERO_RESERVE0");
        priceE18 = (reserve1 * 1e18) / reserve0;
    }
}

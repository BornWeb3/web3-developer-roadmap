// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Pair {
    using SafeERC20 for IERC20;

    address public immutable token0;
    address public immutable token1;

    uint112 private reserve0;
    uint112 private reserve1;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amountIn0,
        uint256 amountIn1,
        uint256 amountOut0,
        uint256 amountOut1,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor(address _token0, address _token1) {
        require(_token0 != address(0), "ZERO_TOKEN0");
        require(_token1 != address(0), "ZERO_TOKEN1");
        require(_token0 != _token1, "IDENTICAL_TOKENS");

        token0 = _token0;
        token1 = _token1;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }

    function _update(uint256 balance0, uint256 balance1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "OVERFLOW");
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        emit Sync(reserve0, reserve1);
    }

    function _mint(address to, uint256 liquidity) private {
        totalSupply += liquidity;
        balanceOf[to] += liquidity;
    }

    function _burn(address from, uint256 liquidity) private {
        balanceOf[from] -= liquidity;
        totalSupply -= liquidity;
    }

    function mint(address to) external returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1) = getReserves();

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        if (totalSupply == 0) {
            liquidity = _sqrt(amount0 * amount1);
        } else {
            uint256 liquidity0 = (amount0 * totalSupply) / _reserve0;
            uint256 liquidity1 = (amount1 * totalSupply) / _reserve1;
            liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
        }

        require(liquidity > 0, "INSUFFICIENT_LIQUIDITY_MINTED");

        _mint(to, liquidity);
        _update(balance0, balance1);

        emit Mint(msg.sender, amount0, amount1);
    }

    function burn(address to) external returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1) = getReserves();

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 liquidity = balanceOf[address(this)];

        amount0 = (liquidity * balance0) / totalSupply;
        amount1 = (liquidity * balance1) / totalSupply;

        require(amount0 > 0 && amount1 > 0, "INSUFFICIENT_LIQUIDITY_BURNED");

        _burn(address(this), liquidity);

        IERC20(token0).safeTransfer(to, amount0);
        IERC20(token1).safeTransfer(to, amount1);

        balance0 = IERC20(token0).balanceOf(address(this));
        balance1 = IERC20(token1).balanceOf(address(this));

        _update(balance0, balance1);

        emit Burn(msg.sender, amount0, amount1, to);
    }

    function swap(uint256 amountOut0, uint256 amountOut1, address to) external {
        require(amountOut0 > 0 || amountOut1 > 0, "INSUFFICIENT_OUTPUT_AMOUNT");

        (uint112 _reserve0, uint112 _reserve1) = getReserves();

        require(amountOut0 < _reserve0 && amountOut1 < _reserve1, "INSUFFICIENT_LIQUIDITY");

        if (amountOut0 > 0) {
            IERC20(token0).safeTransfer(to, amountOut0);
        }
        if (amountOut1 > 0) {
            IERC20(token1).safeTransfer(to, amountOut1);
        }

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amountIn0 = balance0 > (_reserve0 - amountOut0) ? balance0 - (_reserve0 - amountOut0) : 0;
        uint256 amountIn1 = balance1 > (_reserve1 - amountOut1) ? balance1 - (_reserve1 - amountOut1) : 0;

        require(amountIn0 > 0 || amountIn1 > 0, "INSUFFICIENT_INPUT_AMOUNT");

        uint256 balance0Adjusted = (balance0 * 1000) - (amountIn0 * 3);
        uint256 balance1Adjusted = (balance1 * 1000) - (amountIn1 * 3);

        require(
            balance0Adjusted * balance1Adjusted >= uint256(_reserve0) * uint256(_reserve1) * (1000 ** 2),
            "K"
        );

        _update(balance0, balance1);

        emit Swap(msg.sender, amountIn0, amountIn1, amountOut0, amountOut1, to);
    }

    function _sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = (y / 2) + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

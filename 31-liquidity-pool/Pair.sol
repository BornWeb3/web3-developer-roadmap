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

    uint32 private blockTimestampLast;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor(address _token0, address _token1) {
        require(_token0 != _token1, "IDENTICAL_ADDRESSES");

        token0 = _token0;
        token1 = _token1;
    }

    function getReserves()
        public
        view
        returns (uint112 _reserve0, uint112 _reserve1)
    {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }

    function _update(uint256 balance0, uint256 balance1) private {
        require(balance0 <= type(uint112).max, "OVERFLOW");
        require(balance1 <= type(uint112).max, "OVERFLOW");

        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);

        blockTimestampLast = uint32(block.timestamp);

        emit Sync(reserve0, reserve1);
    }

    function mint(address to) external returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1) = getReserves();

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        amount0 = balance0 - _reserve0;
        amount1 = balance1 - _reserve1;

        require(amount0 > 0 && amount1 > 0, "INSUFFICIENT_LIQUIDITY_MINTED");

        _update(balance0, balance1);

        emit Mint(msg.sender, amount0, amount1);
    }

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        (uint112 _reserve0, uint112 _reserve1) = getReserves();

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        amount0 = balance0 - _reserve0;
        amount1 = balance1 - _reserve1;

        require(amount0 > 0 && amount1 > 0, "INSUFFICIENT_LIQUIDITY_BURNED");

        IERC20(token0).safeTransfer(to, amount0);
        IERC20(token1).safeTransfer(to, amount1);

        balance0 = IERC20(token0).balanceOf(address(this));
        balance1 = IERC20(token1).balanceOf(address(this));

        _update(balance0, balance1);

        emit Burn(msg.sender, amount0, amount1, to);
    }

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to
    ) external {
        require(amount0Out > 0 || amount1Out > 0, "INSUFFICIENT_OUTPUT");

        (uint112 _reserve0, uint112 _reserve1) = getReserves();

        require(amount0Out < _reserve0 && amount1Out < _reserve1, "INSUFFICIENT_LIQUIDITY");

        if (amount0Out > 0) {
            IERC20(token0).safeTransfer(to, amount0Out);
        }

        if (amount1Out > 0) {
            IERC20(token1).safeTransfer(to, amount1Out);
        }

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amount0In = balance0 > (_reserve0 - amount0Out)
            ? balance0 - (_reserve0 - amount0Out)
            : 0;

        uint256 amount1In = balance1 > (_reserve1 - amount1Out)
            ? balance1 - (_reserve1 - amount1Out)
            : 0;

        require(amount0In > 0 || amount1In > 0, "INSUFFICIENT_INPUT");

        _update(balance0, balance1);

        emit Swap(
            msg.sender,
            amount0In,
            amount1In,
            amount0Out,
            amount1Out,
            to
        );
    }
}

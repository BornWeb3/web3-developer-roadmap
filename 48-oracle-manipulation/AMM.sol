// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AMM {
    using SafeERC20 for IERC20;

    uint256 private constant ONE = 1e18;

    address public immutable token;
    address public immutable stable;

    uint256 public reserveToken;
    uint256 public reserveStable;

    event LiquidityAdded(
        address indexed provider,
        uint256 tokenAmount,
        uint256 stableAmount
    );

    event Swapped(
        address indexed user,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 amountOut
    );

    event ReservesUpdated(
        uint256 reserveToken,
        uint256 reserveStable
    );

    constructor(address _token, address _stable) {
        require(_token != address(0), "ZERO_TOKEN");
        require(_stable != address(0), "ZERO_STABLE");
        require(_token != _stable, "IDENTICAL_TOKENS");

        token = _token;
        stable = _stable;
    }

    function addLiquidity(
        uint256 tokenAmount,
        uint256 stableAmount
    ) external {
        require(tokenAmount > 0, "ZERO_TOKEN_AMOUNT");
        require(stableAmount > 0, "ZERO_STABLE_AMOUNT");

        IERC20(token).safeTransferFrom(
            msg.sender,
            address(this),
            tokenAmount
        );

        IERC20(stable).safeTransferFrom(
            msg.sender,
            address(this),
            stableAmount
        );

        _updateReserves();

        emit LiquidityAdded(
            msg.sender,
            tokenAmount,
            stableAmount
        );
    }

    function swap(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    )
        external
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "ZERO_AMOUNT_IN");
        require(
            tokenIn == token || tokenIn == stable,
            "INVALID_TOKEN_IN"
        );

        require(
            reserveToken > 0 &&
            reserveStable > 0,
            "EMPTY_POOL"
        );

        if (tokenIn == token) {
            amountOut = _getAmountOut(
                amountIn,
                reserveToken,
                reserveStable
            );

            require(
                amountOut >= minAmountOut,
                "SLIPPAGE"
            );

            IERC20(token).safeTransferFrom(
                msg.sender,
                address(this),
                amountIn
            );

            IERC20(stable).safeTransfer(
                msg.sender,
                amountOut
            );
        } else {
            amountOut = _getAmountOut(
                amountIn,
                reserveStable,
                reserveToken
            );

            require(
                amountOut >= minAmountOut,
                "SLIPPAGE"
            );

            IERC20(stable).safeTransferFrom(
                msg.sender,
                address(this),
                amountIn
            );

            IERC20(token).safeTransfer(
                msg.sender,
                amountOut
            );
        }

        _updateReserves();

        emit Swapped(
            msg.sender,
            tokenIn,
            amountIn,
            amountOut
        );
    }

    function getPrice()
        external
        view
        returns (uint256 priceE18)
    {
        require(
            reserveToken > 0 &&
            reserveStable > 0,
            "EMPTY_POOL"
        );

        priceE18 =
            (reserveStable * ONE) /
            reserveToken;
    }

    function _updateReserves() internal {
        reserveToken =
            IERC20(token).balanceOf(address(this));

        reserveStable =
            IERC20(stable).balanceOf(address(this));

        emit ReservesUpdated(
            reserveToken,
            reserveStable
        );
    }

    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    )
        internal
        pure
        returns (uint256 amountOut)
    {
        amountOut =
            (amountIn * reserveOut) /
            (reserveIn + amountIn);

        require(
            amountOut > 0,
            "ZERO_AMOUNT_OUT"
        );
    }
}

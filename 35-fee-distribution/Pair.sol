// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Pair {
    using SafeERC20 for IERC20;

    uint256 public constant BPS = 10_000;
    uint256 private constant ONE = 1e18;

    address public immutable token0;
    address public immutable token1;
    address public immutable owner;

    uint256 public reserve0;
    uint256 public reserve1;

    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidityBalance;

    uint256 public totalFeeBps;
    uint256 public lpFeeBps;
    uint256 public protocolFeeBps;

    address public protocolFeeRecipient;

    event LiquidityAdded(
        address indexed user,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidityMinted
    );
    event LiquidityRemoved(
        address indexed user,
        uint256 liquidityBurned,
        uint256 amount0,
        uint256 amount1
    );
    event Swapped(
        address indexed user,
        address indexed tokenIn,
        uint256 amountIn,
        address indexed tokenOut,
        uint256 amountOut,
        uint256 minAmountOut
    );
    event SwapFeeDistributed(
        address indexed user,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 totalFeeAmount,
        uint256 lpFeeAmount,
        uint256 protocolFeeAmount,
        address protocolFeeRecipient
    );
    event ReservesUpdated(uint256 reserve0, uint256 reserve1);
    event FeeModelUpdated(
        uint256 totalFeeBps,
        uint256 lpFeeBps,
        uint256 protocolFeeBps,
        address protocolFeeRecipient
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    constructor(
        address _token0,
        address _token1,
        uint256 _totalFeeBps,
        uint256 _lpFeeBps,
        uint256 _protocolFeeBps,
        address _protocolFeeRecipient
    ) {
        require(_token0 != address(0), "ZERO_TOKEN0");
        require(_token1 != address(0), "ZERO_TOKEN1");
        require(_token0 != _token1, "IDENTICAL_TOKENS");

        token0 = _token0;
        token1 = _token1;
        owner = msg.sender;

        _setFeeModel(_totalFeeBps, _lpFeeBps, _protocolFeeBps, _protocolFeeRecipient);
    }

    function setFeeModel(
        uint256 _totalFeeBps,
        uint256 _lpFeeBps,
        uint256 _protocolFeeBps,
        address _protocolFeeRecipient
    ) external onlyOwner {
        _setFeeModel(_totalFeeBps, _lpFeeBps, _protocolFeeBps, _protocolFeeRecipient);
    }

    function _setFeeModel(
        uint256 _totalFeeBps,
        uint256 _lpFeeBps,
        uint256 _protocolFeeBps,
        address _protocolFeeRecipient
    ) internal {
        require(_totalFeeBps <= 1_000, "FEE_TOO_HIGH");
        require(_lpFeeBps + _protocolFeeBps == _totalFeeBps, "INVALID_FEE_SPLIT");

        if (_protocolFeeBps > 0) {
            require(_protocolFeeRecipient != address(0), "ZERO_PROTOCOL_RECIPIENT");
        }

        totalFeeBps = _totalFeeBps;
        lpFeeBps = _lpFeeBps;
        protocolFeeBps = _protocolFeeBps;
        protocolFeeRecipient = _protocolFeeRecipient;

        emit FeeModelUpdated(_totalFeeBps, _lpFeeBps, _protocolFeeBps, _protocolFeeRecipient);
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

        updateReserves();
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

        updateReserves();
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

        uint256 totalFeeAmount = (amountIn * totalFeeBps) / BPS;
        uint256 lpFeeAmount = (amountIn * lpFeeBps) / BPS;
        uint256 protocolFeeAmount = (amountIn * protocolFeeBps) / BPS;

        totalFeeAmount = lpFeeAmount + protocolFeeAmount;

        uint256 amountInForSwap = amountIn - totalFeeAmount;
        require(amountInForSwap > 0, "ZERO_AMOUNT_IN_FOR_SWAP");

        if (zeroToOne) {
            amountOut = _getAmountOut(amountInForSwap, reserve0, reserve1);
            require(amountOut <= reserve1, "INSUFFICIENT_LIQ1");
            require(amountOut >= minAmountOut, "SLIPPAGE");

            IERC20(token0).safeTransferFrom(msg.sender, address(this), amountIn);

            if (protocolFeeAmount > 0) {
                IERC20(token0).safeTransfer(protocolFeeRecipient, protocolFeeAmount);
            }

            IERC20(token1).safeTransfer(msg.sender, amountOut);

            emit Swapped(msg.sender, token0, amountIn, token1, amountOut, minAmountOut);
            emit SwapFeeDistributed(
                msg.sender,
                token0,
                amountIn,
                totalFeeAmount,
                lpFeeAmount,
                protocolFeeAmount,
                protocolFeeRecipient
            );
        } else {
            amountOut = _getAmountOut(amountInForSwap, reserve1, reserve0);
            require(amountOut <= reserve0, "INSUFFICIENT_LIQ0");
            require(amountOut >= minAmountOut, "SLIPPAGE");

            IERC20(token1).safeTransferFrom(msg.sender, address(this), amountIn);

            if (protocolFeeAmount > 0) {
                IERC20(token1).safeTransfer(protocolFeeRecipient, protocolFeeAmount);
            }

            IERC20(token0).safeTransfer(msg.sender, amountOut);

            emit Swapped(msg.sender, token1, amountIn, token0, amountOut, minAmountOut);
            emit SwapFeeDistributed(
                msg.sender,
                token1,
                amountIn,
                totalFeeAmount,
                lpFeeAmount,
                protocolFeeAmount,
                protocolFeeRecipient
            );
        }

        updateReserves();
    }

    function quoteFeeSplit(uint256 amountIn)
        external
        view
        returns (uint256 totalFeeAmount, uint256 lpFeeAmount, uint256 protocolFeeAmount)
    {
        totalFeeAmount = (amountIn * totalFeeBps) / BPS;
        lpFeeAmount = (amountIn * lpFeeBps) / BPS;
        protocolFeeAmount = (amountIn * protocolFeeBps) / BPS;

        totalFeeAmount = lpFeeAmount + protocolFeeAmount;
    }

    function getAmountOut(address tokenIn, uint256 amountIn) external view returns (uint256 amountOut) {
        require(amountIn > 0, "ZERO_AMOUNT_IN");
        require(tokenIn == token0 || tokenIn == token1, "INVALID_TOKEN_IN");
        require(reserve0 > 0 && reserve1 > 0, "EMPTY_POOL");

        uint256 lpPart = (amountIn * lpFeeBps) / BPS;
        uint256 protocolPart = (amountIn * protocolFeeBps) / BPS;
        uint256 amountInForSwap = amountIn - (lpPart + protocolPart);
        require(amountInForSwap > 0, "ZERO_AMOUNT_IN_FOR_SWAP");

        if (tokenIn == token0) {
            amountOut = _getAmountOut(amountInForSwap, reserve0, reserve1);
        } else {
            amountOut = _getAmountOut(amountInForSwap, reserve1, reserve0);
        }
    }

    function getAmountOutNoFee(address tokenIn, uint256 amountIn) external view returns (uint256 amountOut) {
        require(amountIn > 0, "ZERO_AMOUNT_IN");
        require(tokenIn == token0 || tokenIn == token1, "INVALID_TOKEN_IN");
        require(reserve0 > 0 && reserve1 > 0, "EMPTY_POOL");

        if (tokenIn == token0) {
            amountOut = _getAmountOut(amountIn, reserve0, reserve1);
        } else {
            amountOut = _getAmountOut(amountIn, reserve1, reserve0);
        }
    }

    function getSpotPrice(address baseToken) external view returns (uint256 priceE18) {
        require(baseToken == token0 || baseToken == token1, "INVALID_BASE_TOKEN");
        require(reserve0 > 0 && reserve1 > 0, "EMPTY_POOL");

        if (baseToken == token0) {
            priceE18 = (reserve1 * ONE) / reserve0;
        } else {
            priceE18 = (reserve0 * ONE) / reserve1;
        }
    }

    function getK() external view returns (uint256 k) {
        k = reserve0 * reserve1;
    }

    function updateReserves() public {
        reserve0 = IERC20(token0).balanceOf(address(this));
        reserve1 = IERC20(token1).balanceOf(address(this));

        emit ReservesUpdated(reserve0, reserve1);
    }

    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
        require(amountOut > 0, "ZERO_AMOUNT_OUT");
    }
}

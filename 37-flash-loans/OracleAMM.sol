// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IExternalOracle {
    function getPrice() external view returns (uint256);
}

contract OracleAMM {
    address public immutable token0;
    address public immutable token1;
    address public immutable oracle;

    uint256 public reserve0;
    uint256 public reserve1;

    event Swapped(
        address indexed user,
        address indexed tokenIn,
        uint256 amountIn,
        address indexed tokenOut,
        uint256 amountOut
    );

    constructor(address _token0, address _token1, address _oracle) {
        require(_token0 != address(0), "ZERO_TOKEN0");
        require(_token1 != address(0), "ZERO_TOKEN1");
        require(_oracle != address(0), "ZERO_ORACLE");
        require(_token0 != _token1, "IDENTICAL_TOKENS");

        token0 = _token0;
        token1 = _token1;
        oracle = _oracle;
    }

    function updateReserves(uint256 _reserve0, uint256 _reserve1) external {
        require(_reserve0 > 0 && _reserve1 > 0, "INVALID_RESERVES");

        reserve0 = _reserve0;
        reserve1 = _reserve1;
    }

    function getAmountOut(address tokenIn, uint256 amountIn) public view returns (uint256 amountOut) {
        require(amountIn > 0, "ZERO_AMOUNT_IN");
        require(tokenIn == token0 || tokenIn == token1, "INVALID_TOKEN");

        uint256 price = IExternalOracle(oracle).getPrice();
        require(price > 0, "INVALID_PRICE");

        if (tokenIn == token0) {
            amountOut = (amountIn * price) / 1e18;
        } else {
            amountOut = (amountIn * 1e18) / price;
        }
    }

    function swap(address tokenIn, uint256 amountIn) external returns (uint256 amountOut) {
        amountOut = getAmountOut(tokenIn, amountIn);

        emit Swapped(
            msg.sender,
            tokenIn,
            amountIn,
            tokenIn == token0 ? token1 : token0,
            amountOut
        );
    }
}

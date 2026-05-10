// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

contract AMM {

    IERC20 public tokenA;
    IERC20 public tokenB;

    uint256 public reserveA;
    uint256 public reserveB;

    event LiquidityAdded(
        address indexed provider,
        uint256 amountA,
        uint256 amountB
    );

    event Swap(
        address indexed user,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOut
    );

    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external {
        require(amountA > 0 && amountB > 0, "INVALID_AMOUNTS");

        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        reserveA += amountA;
        reserveB += amountB;

        emit LiquidityAdded(msg.sender, amountA, amountB);
    }

    function swapAForB(uint256 amountAIn) external {
        require(amountAIn > 0, "INVALID_AMOUNT");

        uint256 amountBOut = (amountAIn * reserveB) /
            (reserveA + amountAIn);

        require(amountBOut > 0, "INSUFFICIENT_OUTPUT");

        tokenA.transferFrom(msg.sender, address(this), amountAIn);
        tokenB.transfer(msg.sender, amountBOut);

        reserveA += amountAIn;
        reserveB -= amountBOut;

        emit Swap(
            msg.sender,
            address(tokenA),
            amountAIn,
            amountBOut
        );
    }

    function swapBForA(uint256 amountBIn) external {
        require(amountBIn > 0, "INVALID_AMOUNT");

        uint256 amountAOut = (amountBIn * reserveA) /
            (reserveB + amountBIn);

        require(amountAOut > 0, "INSUFFICIENT_OUTPUT");

        tokenB.transferFrom(msg.sender, address(this), amountBIn);
        tokenA.transfer(msg.sender, amountAOut);

        reserveB += amountBIn;
        reserveA -= amountAOut;

        emit Swap(
            msg.sender,
            address(tokenB),
            amountBIn,
            amountAOut
        );
    }

    function getPriceAtoB(uint256 amountAIn)
        external
        view
        returns (uint256)
    {
        return (amountAIn * reserveB) / (reserveA + amountAIn);
    }

    function getPriceBtoA(uint256 amountBIn)
        external
        view
        returns (uint256)
    {
        return (amountBIn * reserveA) / (reserveB + amountBIn);
    }
}

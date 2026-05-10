// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IAMM {
    function getPrice()
        external
        view
        returns (uint256 priceE18);
}

contract Lending {
    using SafeERC20 for IERC20;

    uint256 private constant ONE = 1e18;
    uint256 public constant COLLATERAL_FACTOR = 50;

    address public immutable amm;
    address public immutable collateralToken;
    address public immutable borrowToken;

    mapping(address => uint256) public collateralBalance;
    mapping(address => uint256) public debtBalance;

    event Borrowed(
        address indexed user,
        uint256 collateralAmount,
        uint256 borrowAmount
    );

    event Repaid(
        address indexed user,
        uint256 repayAmount
    );

    event CollateralWithdrawn(
        address indexed user,
        uint256 amount
    );

    constructor(
        address _amm,
        address _collateralToken,
        address _borrowToken
    ) {
        require(_amm != address(0), "ZERO_AMM");
        require(
            _collateralToken != address(0),
            "ZERO_COLLATERAL"
        );
        require(
            _borrowToken != address(0),
            "ZERO_BORROW"
        );

        amm = _amm;
        collateralToken = _collateralToken;
        borrowToken = _borrowToken;
    }

    function borrow(
        uint256 collateralAmount
    )
        external
        returns (uint256 borrowAmount)
    {
        require(
            collateralAmount > 0,
            "ZERO_COLLATERAL"
        );

        IERC20(collateralToken)
            .safeTransferFrom(
                msg.sender,
                address(this),
                collateralAmount
            );

        uint256 price =
            IAMM(amm).getPrice();

        uint256 collateralValue =
            (collateralAmount * price) /
            ONE;

        borrowAmount =
            (collateralValue *
                COLLATERAL_FACTOR) /
            100;

        require(
            borrowAmount > 0,
            "ZERO_BORROW_AMOUNT"
        );

        require(
            IERC20(borrowToken).balanceOf(
                address(this)
            ) >= borrowAmount,
            "INSUFFICIENT_LIQUIDITY"
        );

        collateralBalance[msg.sender] +=
            collateralAmount;

        debtBalance[msg.sender] +=
            borrowAmount;

        IERC20(borrowToken).safeTransfer(
            msg.sender,
            borrowAmount
        );

        emit Borrowed(
            msg.sender,
            collateralAmount,
            borrowAmount
        );
    }

    function repay(
        uint256 repayAmount
    ) external {
        require(
            repayAmount > 0,
            "ZERO_REPAY"
        );

        uint256 userDebt =
            debtBalance[msg.sender];

        require(
            userDebt >= repayAmount,
            "REPAY_TOO_MUCH"
        );

        IERC20(borrowToken)
            .safeTransferFrom(
                msg.sender,
                address(this),
                repayAmount
            );

        debtBalance[msg.sender] =
            userDebt - repayAmount;

        emit Repaid(
            msg.sender,
            repayAmount
        );
    }

    function withdrawCollateral(
        uint256 amount
    ) external {
        require(amount > 0, "ZERO_AMOUNT");

        uint256 collateral =
            collateralBalance[msg.sender];

        require(
            collateral >= amount,
            "INSUFFICIENT_COLLATERAL"
        );

        require(
            debtBalance[msg.sender] == 0,
            "OUTSTANDING_DEBT"
        );

        collateralBalance[msg.sender] =
            collateral - amount;

        IERC20(collateralToken)
            .safeTransfer(
                msg.sender,
                amount
            );

        emit CollateralWithdrawn(
            msg.sender,
            amount
        );
    }

    function getCollateralValue(
        uint256 collateralAmount
    )
        external
        view
        returns (uint256 value)
    {
        uint256 price =
            IAMM(amm).getPrice();

        value =
            (collateralAmount * price) /
            ONE;
    }
}

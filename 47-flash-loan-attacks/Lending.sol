// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
interface IPriceOracle {
    function getPrice() external view returns (uint256 priceE18);
}
contract Lending {
    using SafeERC20 for IERC20;
    IERC20 public immutable collateralToken;
    IERC20 public immutable debtToken;
    IPriceOracle public immutable oracle;
    uint256 public constant COLLATERAL_FACTOR = 50;
    uint256 public constant PRECISION = 1e18;
    mapping(address => uint256) public collateralBalance;
    mapping(address => uint256) public debtBalance;
    event Borrow(
        address indexed borrower,
        uint256 collateralAmount,
        uint256 debtAmount
    );
    event Repay(address indexed borrower, uint256 debtAmount);
    event Liquidate(address indexed borrower, address indexed liquidator);
    constructor(
        address _collateralToken,
        address _debtToken,
        address _oracle
    ) {
        require(_collateralToken != address(0), "ZERO_COLLATERAL");
        require(_debtToken != address(0), "ZERO_DEBT");
        require(_oracle != address(0), "ZERO_ORACLE");
        collateralToken = IERC20(_collateralToken);
        debtToken = IERC20(_debtToken);
        oracle = IPriceOracle(_oracle);
    }
    function borrow(uint256 collateralAmount)
        external
        returns (uint256 debtAmount)
    {
        require(collateralAmount > 0, "ZERO_COLLATERAL");
        collateralToken.safeTransferFrom(
            msg.sender,
            address(this),
            collateralAmount
        );
        uint256 price = oracle.getPrice();
        debtAmount = (collateralAmount * price * COLLATERAL_FACTOR)
            / 100
            / PRECISION;
        require(
            debtToken.balanceOf(address(this)) >= debtAmount,
            "INSUFFICIENT_LIQUIDITY"
        );
        collateralBalance[msg.sender] += collateralAmount;
        debtBalance[msg.sender] += debtAmount;
        debtToken.safeTransfer(msg.sender, debtAmount);
        emit Borrow(msg.sender, collateralAmount, debtAmount);
    }
    function repay(uint256 amount) external {
        require(amount > 0, "ZERO_AMOUNT");
        require(debtBalance[msg.sender] >= amount, "TOO_MUCH_REPAY");
        debtToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 userDebt = debtBalance[msg.sender];
        uint256 userCollateral = collateralBalance[msg.sender];
        uint256 collateralToReturn = (userCollateral * amount) / userDebt;
        debtBalance[msg.sender] -= amount;
        collateralBalance[msg.sender] -= collateralToReturn;
        collateralToken.safeTransfer(msg.sender, collateralToReturn);
        emit Repay(msg.sender, amount);
    }
    function liquidate(address borrower) external {
        require(borrower != address(0), "ZERO_BORROWER");
        uint256 price = oracle.getPrice();
        uint256 collateralValue =
            (collateralBalance[borrower] * price) / PRECISION;
        uint256 maxBorrow = (collateralValue * COLLATERAL_FACTOR) / 100;
        require(debtBalance[borrower] > maxBorrow, "POSITION_HEALTHY");
        uint256 debtAmount = debtBalance[borrower];
        uint256 collateralAmount = collateralBalance[borrower];
        debtToken.safeTransferFrom(msg.sender, address(this), debtAmount);
        debtBalance[borrower] = 0;
        collateralBalance[borrower] = 0;
        collateralToken.safeTransfer(msg.sender, collateralAmount);
        emit Liquidate(borrower, msg.sender);
    }
    function healthFactor(address borrower)
        external
        view
        returns (uint256)
    {
        uint256 debt = debtBalance[borrower];
        if (debt == 0) {
            return type(uint256).max;
        }
        uint256 price = oracle.getPrice();
        uint256 collateralValue =
            (collateralBalance[borrower] * price) / PRECISION;
        return (collateralValue * COLLATERAL_FACTOR) / 100 / debt;
    }
}

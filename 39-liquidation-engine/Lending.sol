// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IPriceOracle {
    function getPrice() external view returns (uint256 priceE18);
}

contract Lending {
    using SafeERC20 for IERC20;

    uint256 public constant BPS = 10_000;
    uint256 private constant ONE = 1e18;

    address public immutable collateralToken;
    address public immutable debtToken;
    address public immutable priceOracle;

    uint256 public immutable collateralFactorBps;
    uint256 public immutable liquidationThresholdBps;
    uint256 public immutable liquidationBonusBps;

    mapping(address => uint256) public collateralBalance;
    mapping(address => uint256) public debtBalance;

    event DebtLiquidityFunded(address indexed provider, uint256 amount);
    event CollateralDeposited(address indexed user, uint256 amount, uint256 balance);
    event Borrowed(address indexed user, uint256 amount, uint256 debt, uint256 healthFactor);
    event Repaid(address indexed user, uint256 amount, uint256 debt);
    event CollateralWithdrawn(address indexed user, uint256 amount, uint256 balance, uint256 healthFactor);
    event Liquidated(
        address indexed liquidator,
        address indexed user,
        uint256 repaidDebt,
        uint256 seizedCollateral
    );

    constructor(
        address _collateralToken,
        address _debtToken,
        address _priceOracle,
        uint256 _collateralFactorBps,
        uint256 _liquidationThresholdBps,
        uint256 _liquidationBonusBps
    ) {
        require(_collateralToken != address(0), "ZERO_COLLATERAL");
        require(_debtToken != address(0), "ZERO_DEBT");
        require(_priceOracle != address(0), "ZERO_ORACLE");
        require(_collateralToken != _debtToken, "IDENTICAL");
        require(_collateralFactorBps >= BPS, "BAD_CF");
        require(_liquidationThresholdBps >= BPS, "BAD_LT");
        require(_liquidationThresholdBps <= _collateralFactorBps, "BAD_CONFIG");

        collateralToken = _collateralToken;
        debtToken = _debtToken;
        priceOracle = _priceOracle;
        collateralFactorBps = _collateralFactorBps;
        liquidationThresholdBps = _liquidationThresholdBps;
        liquidationBonusBps = _liquidationBonusBps;
    }

    function fundDebtLiquidity(uint256 amount) external {
        require(amount > 0, "ZERO");
        IERC20(debtToken).safeTransferFrom(msg.sender, address(this), amount);
        emit DebtLiquidityFunded(msg.sender, amount);
    }

    function depositCollateral(uint256 amount) external {
        require(amount > 0, "ZERO");
        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), amount);

        collateralBalance[msg.sender] += amount;

        emit CollateralDeposited(msg.sender, amount, collateralBalance[msg.sender]);
    }

    function borrow(uint256 amount) external {
        require(amount > 0, "ZERO");

        uint256 newDebt = debtBalance[msg.sender] + amount;
        require(newDebt <= _getMaxBorrow(msg.sender), "OVER_BORROW");

        debtBalance[msg.sender] = newDebt;
        IERC20(debtToken).safeTransfer(msg.sender, amount);

        emit Borrowed(msg.sender, amount, newDebt, getHealthFactor(msg.sender));
    }

    function repay(uint256 amount) external {
        require(amount > 0, "ZERO");

        uint256 debt = debtBalance[msg.sender];
        require(debt > 0, "NO_DEBT");

        uint256 pay = amount > debt ? debt : amount;

        IERC20(debtToken).safeTransferFrom(msg.sender, address(this), pay);
        debtBalance[msg.sender] = debt - pay;

        emit Repaid(msg.sender, pay, debtBalance[msg.sender]);
    }

    function withdrawCollateral(uint256 amount) external {
        require(amount > 0, "ZERO");
        require(collateralBalance[msg.sender] >= amount, "INSUFFICIENT");

        collateralBalance[msg.sender] -= amount;

        uint256 hf = getHealthFactor(msg.sender);
        if (debtBalance[msg.sender] > 0) {
            require(hf >= liquidationThresholdBps, "LOW_HF");
        }

        IERC20(collateralToken).safeTransfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, amount, collateralBalance[msg.sender], hf);
    }

    function liquidate(address user, uint256 repayAmount) external {
        require(repayAmount > 0, "ZERO");
        require(getHealthFactor(user) < liquidationThresholdBps, "HEALTHY");

        uint256 debt = debtBalance[user];
        uint256 pay = repayAmount > debt ? debt : repayAmount;

        uint256 price = IPriceOracle(priceOracle).getPrice();

        uint256 collateralEquivalent = (pay * ONE) / price;
        uint256 bonus = (collateralEquivalent * liquidationBonusBps) / BPS;
        uint256 seize = collateralEquivalent + bonus;

        require(collateralBalance[user] >= seize, "NOT_ENOUGH_COLLATERAL");

        IERC20(debtToken).safeTransferFrom(msg.sender, address(this), pay);

        debtBalance[user] = debt - pay;
        collateralBalance[user] -= seize;

        IERC20(collateralToken).safeTransfer(msg.sender, seize);

        emit Liquidated(msg.sender, user, pay, seize);
    }

    function getHealthFactor(address user) public view returns (uint256) {
        uint256 debt = debtBalance[user];
        if (debt == 0) return type(uint256).max;

        uint256 value = _getCollateralValue(user);
        return (value * BPS) / debt;
    }

    function _getMaxBorrow(address user) internal view returns (uint256) {
        uint256 value = _getCollateralValue(user);
        return (value * BPS) / collateralFactorBps;
    }

    function _getCollateralValue(address user) internal view returns (uint256) {
        uint256 price = IPriceOracle(priceOracle).getPrice();
        return (collateralBalance[user] * price) / ONE;
    }
}

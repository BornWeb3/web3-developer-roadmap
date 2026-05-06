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

    mapping(address => uint256) public collateralBalance;
    mapping(address => uint256) public debtBalance;

    event DebtLiquidityFunded(address indexed provider, uint256 amount);
    event CollateralDeposited(address indexed user, uint256 amount, uint256 userCollateralBalance);
    event Borrowed(address indexed user, uint256 amount, uint256 userDebtBalance, uint256 healthFactorBps);
    event Repaid(address indexed user, uint256 amount, uint256 userDebtBalance);
    event CollateralWithdrawn(address indexed user, uint256 amount, uint256 userCollateralBalance, uint256 healthFactorBps);

    constructor(
        address _collateralToken,
        address _debtToken,
        address _priceOracle,
        uint256 _collateralFactorBps,
        uint256 _liquidationThresholdBps
    ) {
        require(_collateralToken != address(0), "ZERO_COLLATERAL_TOKEN");
        require(_debtToken != address(0), "ZERO_DEBT_TOKEN");
        require(_priceOracle != address(0), "ZERO_ORACLE");
        require(_collateralToken != _debtToken, "IDENTICAL_TOKENS");
        require(_collateralFactorBps >= BPS, "BAD_COLLATERAL_FACTOR");
        require(_liquidationThresholdBps >= BPS, "BAD_LIQ_THRESHOLD");
        require(_liquidationThresholdBps <= _collateralFactorBps, "BAD_RISK_CONFIG");

        collateralToken = _collateralToken;
        debtToken = _debtToken;
        priceOracle = _priceOracle;
        collateralFactorBps = _collateralFactorBps;
        liquidationThresholdBps = _liquidationThresholdBps;
    }

    function fundDebtLiquidity(uint256 amount) external {
        require(amount > 0, "ZERO_AMOUNT");
        IERC20(debtToken).safeTransferFrom(msg.sender, address(this), amount);
        emit DebtLiquidityFunded(msg.sender, amount);
    }

    function depositCollateral(uint256 amount) external {
        require(amount > 0, "ZERO_AMOUNT");
        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), amount);
        collateralBalance[msg.sender] += amount;
        emit CollateralDeposited(msg.sender, amount, collateralBalance[msg.sender]);
    }

    function borrow(uint256 amount) external {
        require(amount > 0, "ZERO_AMOUNT");

        uint256 nextDebt = debtBalance[msg.sender] + amount;
        uint256 maxDebt = _getMaxBorrow(msg.sender);

        require(nextDebt <= maxDebt, "OVER_BORROW");

        debtBalance[msg.sender] = nextDebt;
        IERC20(debtToken).safeTransfer(msg.sender, amount);

        emit Borrowed(msg.sender, amount, nextDebt, getHealthFactor(msg.sender));
    }

    function repay(uint256 amount) external {
        require(amount > 0, "ZERO_AMOUNT");

        uint256 debt = debtBalance[msg.sender];
        require(debt > 0, "NO_DEBT");

        uint256 actualRepay = amount > debt ? debt : amount;

        IERC20(debtToken).safeTransferFrom(msg.sender, address(this), actualRepay);
        debtBalance[msg.sender] = debt - actualRepay;

        emit Repaid(msg.sender, actualRepay, debtBalance[msg.sender]);
    }

    function withdrawCollateral(uint256 amount) external {
        require(amount > 0, "ZERO_AMOUNT");
        require(collateralBalance[msg.sender] >= amount, "INSUFFICIENT_COLLATERAL");

        collateralBalance[msg.sender] -= amount;

        uint256 health = getHealthFactor(msg.sender);

        if (debtBalance[msg.sender] > 0) {
            require(health >= liquidationThresholdBps, "HEALTH_TOO_LOW");
        }

        IERC20(collateralToken).safeTransfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, amount, collateralBalance[msg.sender], health);
    }

    function getHealthFactor(address user) public view returns (uint256 healthFactorBps) {
        uint256 debt = debtBalance[user];

        if (debt == 0) {
            return type(uint256).max;
        }

        uint256 collateralValue = _getCollateralValue(user);
        return (collateralValue * BPS) / debt;
    }

    function getMaxBorrow(address user) external view returns (uint256) {
        return _getMaxBorrow(user);
    }

    function getCollateralValue(address user) external view returns (uint256) {
        return _getCollateralValue(user);
    }

    function getOraclePrice() external view returns (uint256) {
        return ILesson39PriceOracle(priceOracle).getPrice();
    }

    function getDebtLiquidity() external view returns (uint256) {
        return IERC20(debtToken).balanceOf(address(this));
    }

    function _getMaxBorrow(address user) internal view returns (uint256) {
        uint256 collateralValue = _getCollateralValue(user);
        return (collateralValue * BPS) / collateralFactorBps;
    }

    function _getCollateralValue(address user) internal view returns (uint256) {
        uint256 priceE18 = IPriceOracle(priceOracle).getPrice();
        return (collateralBalance[user] * priceE18) / ONE;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IPriceOracle {
    function getPrice() external view returns (uint256 priceE18);
}

contract LendingEdgeCases {
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

    event DebtLiquidityFunded(
        address indexed provider,
        uint256 amount
    );

    event CollateralDeposited(
        address indexed user,
        uint256 amount,
        uint256 userCollateralBalance
    );

    event Borrowed(
        address indexed user,
        uint256 amount,
        uint256 userDebtBalance,
        uint256 healthFactorBps
    );

    event Repaid(
        address indexed user,
        uint256 amount,
        uint256 userDebtBalance
    );

    event CollateralWithdrawn(
        address indexed user,
        uint256 amount,
        uint256 userCollateralBalance,
        uint256 healthFactorBps
    );

    event Liquidated(
        address indexed liquidator,
        address indexed user,
        uint256 repaidDebt,
        uint256 seizedCollateral,
        uint256 userDebtAfter,
        uint256 userCollateralAfter,
        uint256 healthFactorAfter
    );

    constructor(
        address _collateralToken,
        address _debtToken,
        address _priceOracle,
        uint256 _collateralFactorBps,
        uint256 _liquidationThresholdBps,
        uint256 _liquidationBonusBps
    ) {
        require(_collateralToken != address(0), "ZERO_COLLATERAL_TOKEN");
        require(_debtToken != address(0), "ZERO_DEBT_TOKEN");
        require(_priceOracle != address(0), "ZERO_ORACLE");
        require(_collateralToken != _debtToken, "IDENTICAL_TOKENS");

        require(
            _collateralFactorBps >= BPS,
            "BAD_COLLATERAL_FACTOR"
        );

        require(
            _liquidationThresholdBps >= BPS,
            "BAD_LIQ_THRESHOLD"
        );

        require(
            _liquidationThresholdBps <= _collateralFactorBps,
            "BAD_RISK_CONFIG"
        );

        require(
            _liquidationBonusBps <= BPS,
            "BAD_LIQ_BONUS"
        );

        collateralToken = _collateralToken;
        debtToken = _debtToken;
        priceOracle = _priceOracle;

        collateralFactorBps = _collateralFactorBps;
        liquidationThresholdBps = _liquidationThresholdBps;
        liquidationBonusBps = _liquidationBonusBps;
    }

    function fundDebtLiquidity(uint256 amount) external {
        require(amount > 0, "ZERO_AMOUNT");

        IERC20(debtToken).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        emit DebtLiquidityFunded(msg.sender, amount);
    }

    function depositCollateral(uint256 amount) external {
        require(amount > 0, "ZERO_AMOUNT");

        IERC20(collateralToken).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        collateralBalance[msg.sender] += amount;

        emit CollateralDeposited(
            msg.sender,
            amount,
            collateralBalance[msg.sender]
        );
    }

    function borrow(uint256 amount) external {
        require(amount > 0, "ZERO_AMOUNT");

        uint256 nextDebt = debtBalance[msg.sender] + amount;
        uint256 maxDebt = _getMaxBorrow(msg.sender);

        require(nextDebt <= maxDebt, "OVER_BORROW");

        debtBalance[msg.sender] = nextDebt;

        IERC20(debtToken).safeTransfer(
            msg.sender,
            amount
        );

        emit Borrowed(
            msg.sender,
            amount,
            nextDebt,
            getHealthFactor(msg.sender)
        );
    }

    function repay(uint256 amount) external {
        require(amount > 0, "ZERO_AMOUNT");

        uint256 debt = debtBalance[msg.sender];

        require(debt > 0, "NO_DEBT");

        uint256 actualRepay = amount > debt
            ? debt
            : amount;

        IERC20(debtToken).safeTransferFrom(
            msg.sender,
            address(this),
            actualRepay
        );

        debtBalance[msg.sender] =
            debt -
            actualRepay;

        emit Repaid(
            msg.sender,
            actualRepay,
            debtBalance[msg.sender]
        );
    }

    function withdrawCollateral(uint256 amount) external {
        require(amount > 0, "ZERO_AMOUNT");

        require(
            collateralBalance[msg.sender] >= amount,
            "INSUFFICIENT_COLLATERAL"
        );

        collateralBalance[msg.sender] -= amount;

        uint256 health = getHealthFactor(msg.sender);

        if (debtBalance[msg.sender] > 0) {
            require(
                health >= liquidationThresholdBps,
                "HEALTH_TOO_LOW"
            );
        }

        IERC20(collateralToken).safeTransfer(
            msg.sender,
            amount
        );

        emit CollateralWithdrawn(
            msg.sender,
            amount,
            collateralBalance[msg.sender],
            health
        );
    }

    function canLiquidate(address user)
        public
        view
        returns (bool)
    {
        uint256 debt = debtBalance[user];

        if (debt == 0) {
            return false;
        }

        return getHealthFactor(user) <
            liquidationThresholdBps;
    }

    function previewLiquidation(
        address user,
        uint256 requestedRepay
    )
        public
        view
        returns (
            uint256 actualRepay,
            uint256 collateralToTake,
            uint256 debtAfter,
            uint256 collateralAfter,
            bool cappedByCollateral
        )
    {
        require(user != address(0), "ZERO_USER");
        require(requestedRepay > 0, "ZERO_AMOUNT");

        uint256 debt = debtBalance[user];
        uint256 collateral = collateralBalance[user];

        require(debt > 0, "NO_DEBT");

        actualRepay = requestedRepay > debt
            ? debt
            : requestedRepay;

        collateralToTake =
            _debtToCollateralWithBonus(actualRepay);

        if (collateralToTake > collateral) {
            cappedByCollateral = true;
            collateralToTake = collateral;

            actualRepay =
                (_collateralToDebt(collateralToTake) *
                    BPS) /
                (BPS + liquidationBonusBps);

            require(
                actualRepay > 0,
                "REPAY_TOO_SMALL"
            );
        }

        require(
            collateralToTake > 0,
            "SEIZE_TOO_SMALL"
        );

        debtAfter = debt - actualRepay;
        collateralAfter =
            collateral -
            collateralToTake;
    }

    function liquidate(
        address user,
        uint256 repayAmount
    ) external {
        require(user != address(0), "ZERO_USER");

        require(
            user != msg.sender,
            "SELF_LIQUIDATION_BLOCKED"
        );

        require(repayAmount > 0, "ZERO_AMOUNT");

        require(
            canLiquidate(user),
            "HEALTHY_POSITION"
        );

        (
            uint256 actualRepay,
            uint256 collateralToTake,
            uint256 debtAfter,
            uint256 collateralAfter,
            bool cappedByCollateral
        ) = previewLiquidation(
                user,
                repayAmount
            );

        if (cappedByCollateral) {
            require(
                collateralAfter == 0,
                "CAP_STATE_MISMATCH"
            );
        }

        debtBalance[user] = debtAfter;
        collateralBalance[user] =
            collateralAfter;

        IERC20(debtToken).safeTransferFrom(
            msg.sender,
            address(this),
            actualRepay
        );

        IERC20(collateralToken).safeTransfer(
            msg.sender,
            collateralToTake
        );

        emit Liquidated(
            msg.sender,
            user,
            actualRepay,
            collateralToTake,
            debtAfter,
            collateralAfter,
            getHealthFactor(user)
        );
    }

    function getPositionState(
        address user
    )
        external
        view
        returns (
            uint256 collateral,
            uint256 debt,
            uint256 collateralValue,
            uint256 healthFactorBps,
            bool liquidatable,
            uint256 thresholdBps,
            uint256 priceE18
        )
    {
        collateral = collateralBalance[user];
        debt = debtBalance[user];

        priceE18 =
            IPriceOracle(priceOracle)
                .getPrice();

        collateralValue =
            (collateral * priceE18) /
            ONE;

        if (debt == 0) {
            healthFactorBps =
                type(uint256).max;

            liquidatable = false;
        } else {
            healthFactorBps =
                (collateralValue * BPS) /
                debt;

            liquidatable =
                healthFactorBps <
                liquidationThresholdBps;
        }

        thresholdBps =
            liquidationThresholdBps;
    }

    function getHealthFactor(
        address user
    )
        public
        view
        returns (uint256 healthFactorBps)
    {
        uint256 debt = debtBalance[user];

        if (debt == 0) {
            return type(uint256).max;
        }

        uint256 collateralValue =
            _getCollateralValue(user);

        healthFactorBps =
            (collateralValue * BPS) /
            debt;
    }

    function getMaxBorrow(
        address user
    )
        external
        view
        returns (uint256 maxBorrowAmount)
    {
        maxBorrowAmount =
            _getMaxBorrow(user);
    }

    function getCollateralValue(
        address user
    )
        external
        view
        returns (uint256 collateralValue)
    {
        collateralValue =
            _getCollateralValue(user);
    }

    function getOraclePrice()
        external
        view
        returns (uint256 priceE18)
    {
        priceE18 =
            IPriceOracle(priceOracle)
                .getPrice();
    }

    function getDebtLiquidity()
        external
        view
        returns (uint256 liquidity)
    {
        liquidity = IERC20(debtToken)
            .balanceOf(address(this));
    }

    function _getMaxBorrow(
        address user
    )
        internal
        view
        returns (uint256 maxBorrowAmount)
    {
        uint256 collateralValue =
            _getCollateralValue(user);

        maxBorrowAmount =
            (collateralValue * BPS) /
            collateralFactorBps;
    }

    function _getCollateralValue(
        address user
    )
        internal
        view
        returns (uint256 collateralValue)
    {
        uint256 priceE18 =
            IPriceOracle(priceOracle)
                .getPrice();

        collateralValue =
            (collateralBalance[user] *
                priceE18) /
            ONE;
    }

    function _debtToCollateralWithBonus(
        uint256 debtAmount
    )
        internal
        view
        returns (uint256 collateralAmount)
    {
        uint256 priceE18 =
            IPriceOracle(priceOracle)
                .getPrice();

        uint256 baseCollateral =
            (debtAmount * ONE) /
            priceE18;

        collateralAmount =
            (baseCollateral *
                (BPS + liquidationBonusBps)) /
            BPS;
    }

    function _collateralToDebt(
        uint256 collateralAmount
    )
        internal
        view
        returns (uint256 debtAmount)
    {
        uint256 priceE18 =
            IPriceOracle(priceOracle)
                .getPrice();

        debtAmount =
            (collateralAmount * priceE18) /
            ONE;
    }
}

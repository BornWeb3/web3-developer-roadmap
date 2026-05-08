// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IPriceOracle {
    function getPrice() external view returns (uint256);
}

contract Lending {
    IERC20 public immutable collateralToken;
    IERC20 public immutable borrowToken;
    IPriceOracle public immutable oracle;

    uint256 public constant PRECISION = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 75;
    uint256 public constant LIQUIDATION_BONUS = 5;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;

    struct Position {
        uint256 collateralAmount;
        uint256 borrowedAmount;
    }

    mapping(address => Position) public positions;

    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event Liquidated(
        address indexed liquidator,
        address indexed user,
        uint256 repaidAmount,
        uint256 collateralSeized
    );

    constructor(
        address _collateralToken,
        address _borrowToken,
        address _oracle
    ) {
        collateralToken = IERC20(_collateralToken);
        borrowToken = IERC20(_borrowToken);
        oracle = IPriceOracle(_oracle);
    }

    function depositCollateral(uint256 amount) external {
        require(amount > 0, "amount = 0");

        collateralToken.transferFrom(msg.sender, address(this), amount);

        positions[msg.sender].collateralAmount += amount;

        emit CollateralDeposited(msg.sender, amount);
    }

    function withdrawCollateral(uint256 amount) external {
        Position storage position = positions[msg.sender];

        require(amount > 0, "amount = 0");
        require(position.collateralAmount >= amount, "not enough collateral");

        position.collateralAmount -= amount;

        require(_healthFactor(msg.sender) >= MIN_HEALTH_FACTOR, "health factor too low");

        collateralToken.transfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, amount);
    }

    function borrow(uint256 amount) external {
        require(amount > 0, "amount = 0");

        Position storage position = positions[msg.sender];

        position.borrowedAmount += amount;

        require(_healthFactor(msg.sender) >= MIN_HEALTH_FACTOR, "insufficient collateral");

        borrowToken.transfer(msg.sender, amount);

        emit Borrowed(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        require(amount > 0, "amount = 0");

        Position storage position = positions[msg.sender];

        require(position.borrowedAmount >= amount, "repay too much");

        borrowToken.transferFrom(msg.sender, address(this), amount);

        position.borrowedAmount -= amount;

        emit Repaid(msg.sender, amount);
    }

    function liquidate(address user, uint256 repayAmount) external {
        require(_healthFactor(user) < MIN_HEALTH_FACTOR, "position healthy");

        Position storage position = positions[user];

        require(repayAmount > 0, "amount = 0");
        require(position.borrowedAmount >= repayAmount, "repay too much");

        uint256 collateralPrice = oracle.getPrice();

        uint256 collateralEquivalent = (repayAmount * PRECISION) / collateralPrice;

        uint256 bonus = (collateralEquivalent * LIQUIDATION_BONUS) / 100;

        uint256 collateralToSeize = collateralEquivalent + bonus;

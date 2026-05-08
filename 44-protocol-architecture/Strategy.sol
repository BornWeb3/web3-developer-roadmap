// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface ILendingProtocol {
    function depositCollateral(uint256 amount) external;
    function withdrawCollateral(uint256 amount) external;
    function borrow(uint256 amount) external;
    function repay(uint256 amount) external;
    function healthFactor(address user) external view returns (uint256);
}

interface IAMM {
    function swap(address tokenIn, uint256 amountIn) external returns (uint256 amountOut);
}

contract Strategy {
    IERC20 public immutable collateralToken;
    IERC20 public immutable borrowToken;
    ILendingProtocol public immutable lending;
    IAMM public immutable amm;

    address public immutable owner;

    uint256 public totalDeposited;
    uint256 public totalBorrowed;

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(
        address _collateralToken,
        address _borrowToken,
        address _lending,
        address _amm
    ) {
        collateralToken = IERC20(_collateralToken);
        borrowToken = IERC20(_borrowToken);
        lending = ILendingProtocol(_lending);
        amm = IAMM(_amm);
        owner = msg.sender;
    }

    function deposit(uint256 amount) external onlyOwner {
        require(amount > 0, "amount = 0");

        collateralToken.transferFrom(msg.sender, address(this), amount);

        collateralToken.transfer(address(lending), amount);
        lending.depositCollateral(amount);

        totalDeposited += amount;
    }

    function leverageLoop(uint256 borrowAmount, uint256 loops) external onlyOwner {
        require(borrowAmount > 0, "amount = 0");
        require(loops > 0, "loops = 0");

        for (uint256 i = 0; i < loops; i++) {
            lending.borrow(borrowAmount);

            totalBorrowed += borrowAmount;

            borrowToken.transfer(address(amm), borrowAmount);

            uint256 collateralReceived = amm.swap(
                address(borrowToken),
                borrowAmount
            );

            collateralToken.transfer(address(lending), collateralReceived);
            lending.depositCollateral(collateralReceived);

            totalDeposited += collateralReceived;
        }
    }

    function deleverage(uint256 repayAmount) external onlyOwner {
        require(repayAmount > 0, "amount = 0");

        lending.withdrawCollateral(repayAmount);

        collateralToken.transfer(address(amm), repayAmount);

        uint256 borrowReceived = amm.swap(
            address(collateralToken),
            repayAmount
        );

        borrowToken.transfer(address(lending), borrowReceived);

        lending.repay(borrowReceived);

        if (borrowReceived >= totalBorrowed) {
            totalBorrowed = 0;
        } else {
            totalBorrowed -= borrowReceived;
        }

        if (repayAmount >= totalDeposited) {
            totalDeposited = 0;
        } else {
            totalDeposited -= repayAmount;
        }
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 collateralBalance = collateralToken.balanceOf(address(this));
        uint256 borrowBalance = borrowToken.balanceOf(address(this));

        if (collateralBalance > 0) {
            collateralToken.transfer(owner, collateralBalance);
        }

        if (borrowBalance > 0) {
            borrowToken.transfer(owner, borrowBalance);
        }
    }

    function getHealthFactor() external view returns (uint256) {
        return lending.healthFactor(address(this));
    }
}

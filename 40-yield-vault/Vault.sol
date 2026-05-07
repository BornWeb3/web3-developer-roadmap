// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IStrategy {
    function depositToStrategy(uint256 amount) external;
    function withdrawFromStrategy(uint256 amount) external;
    function harvest() external returns (uint256 profitHarvested);
}

contract Vault {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;

    address public owner;
    address public strategy;

    uint256 public totalAssets;
    uint256 public totalShares;

    mapping(address => uint256) public balanceOf;

    event StrategyUpdated(
        address indexed previousStrategy,
        address indexed newStrategy
    );

    event Deposited(
        address indexed user,
        uint256 assets,
        uint256 sharesMinted
    );

    event Withdrawn(
        address indexed user,
        uint256 assets,
        uint256 sharesBurned
    );

    event Earned(uint256 sentToStrategy);

    event Harvested(
        uint256 profitHarvested,
        uint256 totalAssetsAfter
    );

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    constructor(
        address _token,
        address _owner
    ) {
        require(_token != address(0), "ZERO_TOKEN");
        require(_owner != address(0), "ZERO_OWNER");

        token = IERC20(_token);
        owner = _owner;

        emit OwnershipTransferred(
            address(0),
            _owner
        );
    }

    function transferOwnership(
        address newOwner
    ) external onlyOwner {
        require(newOwner != address(0), "ZERO_OWNER");

        address previousOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(
            previousOwner,
            newOwner
        );
    }

    function setStrategy(
        address newStrategy
    ) external onlyOwner {
        require(
            newStrategy != address(0),
            "ZERO_STRATEGY"
        );

        address previousStrategy = strategy;
        strategy = newStrategy;

        emit StrategyUpdated(
            previousStrategy,
            newStrategy
        );
    }

    function deposit(
        uint256 amount
    ) external returns (uint256 shares) {
        require(amount > 0, "ZERO_AMOUNT");

        uint256 currentAssets = totalAssets;

        if (
            totalShares == 0 ||
            currentAssets == 0
        ) {
            shares = amount;
        } else {
            shares =
                (amount * totalShares) /
                currentAssets;

            require(
                shares > 0,
                "ZERO_SHARES"
            );
        }

        token.safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        totalAssets = currentAssets + amount;
        totalShares += shares;
        balanceOf[msg.sender] += shares;

        emit Deposited(
            msg.sender,
            amount,
            shares
        );
    }

    function withdraw(
        uint256 shares
    ) external returns (uint256 amountOut) {
        require(shares > 0, "ZERO_SHARES");

        uint256 userShares =
            balanceOf[msg.sender];

        require(
            userShares >= shares,
            "INSUFFICIENT_SHARES"
        );

        require(
            totalShares > 0,
            "NO_SHARES_SUPPLY"
        );

        amountOut =
            (shares * totalAssets) /
            totalShares;

        require(
            amountOut > 0,
            "ZERO_ASSETS_OUT"
        );

        balanceOf[msg.sender] =
            userShares - shares;

        totalShares -= shares;
        totalAssets -= amountOut;

        uint256 idle =
            token.balanceOf(address(this));

        if (idle < amountOut) {
            uint256 shortfall =
                amountOut - idle;

            _pullFromStrategy(shortfall);
        }

        token.safeTransfer(
            msg.sender,
            amountOut
        );

        emit Withdrawn(
            msg.sender,
            amountOut,
            shares
        );
    }

    function earn()
        external
        onlyOwner
        returns (uint256 sent)
    {
        address currentStrategy =
            strategy;

        require(
            currentStrategy != address(0),
            "STRATEGY_NOT_SET"
        );

        sent =
            token.balanceOf(address(this));

        require(
            sent > 0,
            "NO_IDLE_ASSETS"
        );

        token.safeTransfer(
            currentStrategy,
            sent
        );

        IStrategy(currentStrategy)
            .depositToStrategy(sent);

        emit Earned(sent);
    }

    function harvest()
        external
        returns (uint256 profitHarvested)
    {
        address currentStrategy =
            strategy;

        require(
            currentStrategy != address(0),
            "STRATEGY_NOT_SET"
        );

        profitHarvested =
            IStrategy(currentStrategy)
                .harvest();

        if (profitHarvested > 0) {
            totalAssets +=
                profitHarvested;
        }

        emit Harvested(
            profitHarvested,
            totalAssets
        );
    }

    function pricePerShareE18()
        external
        view
        returns (uint256)
    {
        if (totalShares == 0) {
            return 1e18;
        }

        return
            (totalAssets * 1e18) /
            totalShares;
    }

    function idleAssets()
        external
        view
        returns (uint256)
    {
        return token.balanceOf(address(this));
    }

    function _pullFromStrategy(
        uint256 amount
    ) internal {
        address currentStrategy =
            strategy;

        require(
            currentStrategy != address(0),
            "STRATEGY_NOT_SET"
        );

        IStrategy(currentStrategy)
            .withdrawFromStrategy(amount);
    }
}

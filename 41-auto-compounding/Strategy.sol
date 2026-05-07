// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IMintableToken is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract Strategy {
    using SafeERC20 for IERC20;

    address public immutable vault;
    IERC20 public immutable token;
    IMintableToken public immutable mintableToken;
    address public immutable owner;

    uint256 public totalInvested;
    uint256 public pendingProfit;

    event DepositedToStrategy(
        uint256 amount,
        uint256 totalInvestedAfter
    );

    event ProfitSimulated(
        uint256 profit,
        uint256 totalInvestedAfter,
        uint256 pendingProfitAfter
    );

    event WithdrawnToVault(
        uint256 amount,
        uint256 totalInvestedAfter
    );

    event Harvested(
        uint256 profit,
        uint256 pendingProfitAfter,
        uint256 totalInvestedAfter
    );

    modifier onlyVault() {
        require(msg.sender == vault, "NOT_VAULT");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    constructor(
        address _vault,
        address _token,
        address _owner
    ) {
        require(_vault != address(0), "ZERO_VAULT");
        require(_token != address(0), "ZERO_TOKEN");
        require(_owner != address(0), "ZERO_OWNER");

        vault = _vault;
        token = IERC20(_token);
        mintableToken = IMintableToken(_token);
        owner = _owner;
    }

    function depositToStrategy(
        uint256 amount
    ) external onlyVault {
        require(amount > 0, "ZERO_AMOUNT");

        totalInvested += amount;

        emit DepositedToStrategy(
            amount,
            totalInvested
        );
    }

    function simulateProfit(
        uint256 profit
    ) external onlyOwner {
        require(profit > 0, "ZERO_PROFIT");

        mintableToken.mint(
            address(this),
            profit
        );

        totalInvested += profit;
        pendingProfit += profit;

        emit ProfitSimulated(
            profit,
            totalInvested,
            pendingProfit
        );
    }

    function withdrawFromStrategy(
        uint256 amount
    ) external onlyVault {
        require(amount > 0, "ZERO_AMOUNT");

        require(
            amount <= totalInvested,
            "AMOUNT_EXCEEDS_INVESTED"
        );

        totalInvested -= amount;

        token.safeTransfer(
            vault,
            amount
        );

        emit WithdrawnToVault(
            amount,
            totalInvested
        );
    }

    function harvest()
        external
        onlyVault
        returns (uint256 profitHarvested)
    {
        profitHarvested = pendingProfit;

        if (profitHarvested == 0) {
            return 0;
        }

        pendingProfit = 0;
        totalInvested -= profitHarvested;

        token.safeTransfer(
            vault,
            profitHarvested
        );

        emit Harvested(
            profitHarvested,
            pendingProfit,
            totalInvested
        );
    }

    function strategyBalance()
        external
        view
        returns (uint256)
    {
        return token.balanceOf(address(this));
    }
}

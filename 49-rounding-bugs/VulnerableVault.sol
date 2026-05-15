// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract VulnerableVault {
    using SafeERC20 for IERC20;

    address public immutable asset;

    uint256 public totalAssets;
    uint256 public totalShares;

    mapping(address => uint256) public balanceOf;

    event Deposited(address indexed user, uint256 assets, uint256 shares);
    event Withdrawn(address indexed user, uint256 shares, uint256 assets);
    event YieldAdded(uint256 amount);

    constructor(address _asset) {
        require(_asset != address(0), "ZERO_ASSET");
        asset = _asset;
    }

  
    function deposit(uint256 assets) external returns (uint256 shares) {
        require(assets > 0, "ZERO_ASSETS");

        if (totalShares == 0 || totalAssets == 0) {
            shares = assets;
        } else {
            shares = (assets * totalShares) / totalAssets;
        }

        require(shares > 0, "ZERO_SHARES");

        IERC20(asset).safeTransferFrom(msg.sender, address(this), assets);

        balanceOf[msg.sender] += shares;

        totalShares += shares;
        totalAssets += assets;

        emit Deposited(msg.sender, assets, shares);
    }

    function withdraw(uint256 shares) external returns (uint256 assetsOut) {
        require(shares > 0, "ZERO_SHARES");
        require(balanceOf[msg.sender] >= shares, "NOT_ENOUGH_SHARES");

        assetsOut = (shares * totalAssets) / totalShares;

        balanceOf[msg.sender] -= shares;

        totalShares -= shares;
        totalAssets -= assetsOut;

        IERC20(asset).safeTransfer(msg.sender, assetsOut);

        emit Withdrawn(msg.sender, shares, assetsOut);
    }

    function notifyYield(uint256 amount) external {
        require(amount > 0, "ZERO_AMOUNT");

        IERC20(asset).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        totalAssets += amount;

        emit YieldAdded(amount);
    }

    function previewDeposit(uint256 assets) external view returns (uint256 shares) {
        if (assets == 0) return 0;

        if (totalShares == 0 || totalAssets == 0) {
            return assets;
        }

        shares = (assets * totalShares) / totalAssets;
    }

    function previewWithdraw(uint256 shares) external view returns (uint256 assetsOut) {
        if (shares == 0 || totalShares == 0) return 0;

        assetsOut = (shares * totalAssets) / totalShares;
    }
}

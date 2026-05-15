// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FixedVault {
    using SafeERC20 for IERC20;

    uint256 public constant PRECISION = 1e12;
    uint256 public constant MIN_DEPOSIT = 10;

    address public immutable asset;

    uint256 public totalAssets;
    uint256 public totalShares;
    uint256 public assetsPerShareX12;

    mapping(address => uint256) public balanceOf;

    event Deposited(address indexed user, uint256 assets, uint256 shares);
    event Withdrawn(address indexed user, uint256 shares, uint256 assets);
    event YieldNotified(address indexed from, uint256 assets, uint256 totalAssetsAfter);

    constructor(address _asset) {
        require(_asset != address(0), "ZERO_ASSET");
        asset = _asset;
    }

    function deposit(uint256 assets) external returns (uint256 shares) {
        require(assets >= MIN_DEPOSIT, "DEPOSIT_TOO_SMALL");

        if (totalShares == 0 || totalAssets == 0) {
            shares = assets;
        } else {
            uint256 aps = assetsPerShareX12;
            require(aps > 0, "BAD_APS");
            shares = (assets * PRECISION) / aps;
        }

        require(shares > 0, "ZERO_SHARES");

        IERC20(asset).safeTransferFrom(msg.sender, address(this), assets);

        balanceOf[msg.sender] += shares;
        totalShares += shares;
        totalAssets += assets;

        _updateAps();
        emit Deposited(msg.sender, assets, shares);
    }

    function withdraw(uint256 shares) external returns (uint256 assetsOut) {
        require(shares > 0, "ZERO_SHARES");
        require(balanceOf[msg.sender] >= shares, "INSUFFICIENT_SHARES");
        require(totalShares > 0, "NO_SHARES");

        assetsOut = (shares * totalAssets) / totalShares;
        require(assetsOut > 0, "ZERO_ASSETS_OUT");

        balanceOf[msg.sender] -= shares;
        totalShares -= shares;
        totalAssets -= assetsOut;

        IERC20(asset).safeTransfer(msg.sender, assetsOut);

        _updateAps();
        emit Withdrawn(msg.sender, shares, assetsOut);
    }

    function notifyYield(uint256 assets) external {
        require(assets > 0, "ZERO_YIELD");

        IERC20(asset).safeTransferFrom(msg.sender, address(this), assets);
        totalAssets += assets;

        _updateAps();
        emit YieldNotified(msg.sender, assets, totalAssets);
    }

    function previewDeposit(uint256 assets) external view returns (uint256 shares) {
        if (assets == 0) return 0;
        if (totalShares == 0 || totalAssets == 0) return assets;

        if (assets < MIN_DEPOSIT) return 0;
        uint256 aps = assetsPerShareX12;
        if (aps == 0) return 0;

        shares = (assets * PRECISION) / aps;
    }

    function previewWithdraw(uint256 shares) public view returns (uint256 assetsOut) {
        if (shares == 0 || totalShares == 0) return 0;
        assetsOut = (shares * totalAssets) / totalShares;
    }

    function _updateAps() internal {
        if (totalShares == 0 || totalAssets == 0) {
            assetsPerShareX12 = 0;
        } else {
            assetsPerShareX12 = (totalAssets * PRECISION) / totalShares;
        }
    }
}

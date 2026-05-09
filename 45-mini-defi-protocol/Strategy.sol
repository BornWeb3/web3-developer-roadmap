// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
interface IProfitSource {
    function provideYield(uint256 invested, uint256 rewardRateBps) external returns (uint256 rewardAmount);
}
interface IVaultLike {
    function reportProfit(uint256 profitAmount) external;
}
contract Strategy {
    using SafeERC20 for IERC20;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_REWARD_RATE_BPS = 2_000;
    uint256 public constant MAX_FEE_BPS = 2_000;
    address public immutable vault;
    IERC20 public immutable token;
    IProfitSource public immutable profitSource;
    uint256 public totalInvested;
    uint256 public pendingRewards;
    uint256 public rewardRateBps;
    uint256 public performanceFeeBps;
    address public governance;
    address public feeRecipient;
    event GovernanceUpdated(address indexed previousGovernance, address indexed newGovernance);
    event FeeRecipientUpdated(address indexed previousFeeRecipient, address indexed newFeeRecipient);
    event RewardRateUpdated(uint256 previousRateBps, uint256 newRateBps);
    event PerformanceFeeUpdated(uint256 previousFeeBps, uint256 newFeeBps);
    event DepositedToStrategy(uint256 amount, uint256 totalInvestedAfter);
    event WithdrawnToVault(uint256 amount, uint256 totalInvestedAfter);
    event YieldGenerated(uint256 rewardAmount, uint256 pendingRewardsAfter);
    event Harvested(uint256 harvestedRewards, uint256 pendingRewardsAfter);
    event Reinvested(uint256 reinvestedAmount, uint256 feeAmount, uint256 totalInvestedAfter);
    event Compounded(uint256 harvestedRewards, uint256 reinvestedAmount, uint256 feeAmount);
    modifier onlyVault() {
        require(msg.sender == vault, "NOT_VAULT");
        _;
    }
    modifier onlyGovernance() {
        require(msg.sender == governance, "NOT_GOVERNANCE");
        _;
    }
    constructor(
        address vault_,
        address token_,
        address profitSource_,
        address governance_,
        uint256 initialRewardRateBps,
        uint256 initialPerformanceFeeBps,
        address initialFeeRecipient
    ) {
        require(vault_ != address(0), "ZERO_VAULT");
        require(token_ != address(0), "ZERO_TOKEN");
        require(profitSource_ != address(0), "ZERO_PROFIT_SOURCE");
        require(governance_ != address(0), "ZERO_GOVERNANCE");
        require(initialFeeRecipient != address(0), "ZERO_FEE_RECIPIENT");
        require(initialRewardRateBps <= MAX_REWARD_RATE_BPS, "REWARD_RATE_TOO_HIGH");
        require(initialPerformanceFeeBps <= MAX_FEE_BPS, "FEE_TOO_HIGH");
        vault = vault_;
        token = IERC20(token_);
        profitSource = IProfitSource(profitSource_);
        governance = governance_;
        feeRecipient = initialFeeRecipient;
        rewardRateBps = initialRewardRateBps;
        performanceFeeBps = initialPerformanceFeeBps;
        emit GovernanceUpdated(address(0), governance_);
        emit FeeRecipientUpdated(address(0), initialFeeRecipient);
        emit RewardRateUpdated(0, initialRewardRateBps);
        emit PerformanceFeeUpdated(0, initialPerformanceFeeBps);
    }
    function setGovernance(address newGovernance) external onlyGovernance {
        require(newGovernance != address(0), "ZERO_GOVERNANCE");
        address previousGovernance = governance;
        governance = newGovernance;
        emit GovernanceUpdated(previousGovernance, newGovernance);
    }
    function setFeeRecipient(address newFeeRecipient) external onlyGovernance {
        require(newFeeRecipient != address(0), "ZERO_FEE_RECIPIENT");
        address previousFeeRecipient = feeRecipient;
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(previousFeeRecipient, newFeeRecipient);
    }
    function setRewardRateBps(uint256 newRateBps) external onlyGovernance {
        require(newRateBps <= MAX_REWARD_RATE_BPS, "REWARD_RATE_TOO_HIGH");
        uint256 previousRateBps = rewardRateBps;
        rewardRateBps = newRateBps;
        emit RewardRateUpdated(previousRateBps, newRateBps);
    }
    function setPerformanceFeeBps(uint256 newFeeBps) external onlyGovernance {
        require(newFeeBps <= MAX_FEE_BPS, "FEE_TOO_HIGH");
        uint256 previousFeeBps = performanceFeeBps;
        performanceFeeBps = newFeeBps;
        emit PerformanceFeeUpdated(previousFeeBps, newFeeBps);
    }
    function depositToStrategy(uint256 amount) external onlyVault {
        require(amount > 0, "ZERO_AMOUNT");
        totalInvested += amount;
        emit DepositedToStrategy(amount, totalInvested);
    }
    function withdrawToVault(uint256 amount) external onlyVault {
        require(amount > 0, "ZERO_AMOUNT");
        require(amount <= totalInvested, "AMOUNT_EXCEEDS_INVESTED");
        totalInvested -= amount;
        token.safeTransfer(vault, amount);
        emit WithdrawnToVault(amount, totalInvested);
    }
    function generateYield() external returns (uint256 rewardAmount) {
        rewardAmount = profitSource.provideYield(totalInvested, rewardRateBps);
        require(rewardAmount > 0, "NO_YIELD");
        pendingRewards += rewardAmount;
        emit YieldGenerated(rewardAmount, pendingRewards);
    }
    function harvest() public onlyVault returns (uint256 harvestedRewards) {
        harvestedRewards = pendingRewards;
        if (harvestedRewards == 0) {
            return 0;
        }
        pendingRewards = 0;
        emit Harvested(harvestedRewards, pendingRewards);
    }
    function reinvest(uint256 harvestedRewards)
        public
        onlyVault
        returns (uint256 reinvestedAmount, uint256 feeAmount)
    {
        require(harvestedRewards > 0, "ZERO_HARVEST");
        feeAmount = (harvestedRewards * performanceFeeBps) / BPS_DENOMINATOR;
        reinvestedAmount = harvestedRewards - feeAmount;
        if (feeAmount > 0) {
            token.safeTransfer(feeRecipient, feeAmount);
        }
        totalInvested += reinvestedAmount;
        emit Reinvested(reinvestedAmount, feeAmount, totalInvested);
    }
    function compound() external onlyVault returns (uint256 reinvestedAmount, uint256 feeAmount) {
        uint256 harvestedRewards = harvest();
        if (harvestedRewards == 0) {
            return (0, 0);
        }
        (reinvestedAmount, feeAmount) = reinvest(harvestedRewards);
        IVaultLike(vault).reportProfit(reinvestedAmount);
        emit Compounded(harvestedRewards, reinvestedAmount, feeAmount);
    }
    function strategyBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}

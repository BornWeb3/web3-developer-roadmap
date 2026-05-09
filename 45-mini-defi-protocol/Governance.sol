// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IGovToken {
    function balanceOf(address account) external view returns (uint256);
}

interface IGovVault {
    function setStrategy(address newStrategy) external;
}

interface IGovStrategy {
    function setRewardRateBps(uint256 newRateBps) external;

    function setPerformanceFeeBps(uint256 newFeeBps) external;
}

contract Governance {
    enum ProposalType {
        SetStrategy,
        SetRewardRate,
        SetPerformanceFee
    }

    struct Proposal {
        ProposalType proposalType;
        address targetAddress;
        uint256 targetValue;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
    }

    IGovToken public immutable token;
    IGovVault public immutable vault;
    IGovStrategy public immutable strategy;

    uint256 public immutable proposalThreshold;
    uint256 public immutable quorum;
    uint256 public immutable votingDuration;

    uint256 public proposalCount;

    mapping(uint256 => Proposal) private proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        ProposalType proposalType,
        address targetAddress,
        uint256 targetValue,
        string description,
        uint256 startTime,
        uint256 endTime
    );

    event Voted(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 weight
    );

    event ProposalExecuted(
        uint256 indexed proposalId,
        ProposalType proposalType,
        address targetAddress,
        uint256 targetValue,
        uint256 forVotes,
        uint256 againstVotes
    );

    constructor(
        address tokenAddress,
        address vaultAddress,
        address strategyAddress,
        uint256 creationThreshold,
        uint256 minQuorum,
        uint256 durationSeconds
    ) {
        require(tokenAddress != address(0), "ZERO_TOKEN");
        require(vaultAddress != address(0), "ZERO_VAULT");
        require(strategyAddress != address(0), "ZERO_STRATEGY");
        require(durationSeconds > 0, "ZERO_DURATION");

        token = IGovToken(tokenAddress);
        vault = IGovVault(vaultAddress);
        strategy = IGovStrategy(strategyAddress);

        proposalThreshold = creationThreshold;
        quorum = minQuorum;
        votingDuration = durationSeconds;
    }

    function createProposal(
        ProposalType proposalType,
        address targetAddress,
        uint256 targetValue,
        string calldata description
    ) external returns (uint256 proposalId) {
        require(bytes(description).length > 0, "EMPTY_DESCRIPTION");
        require(
            token.balanceOf(msg.sender) >= proposalThreshold,
            "INSUFFICIENT_POWER_TO_PROPOSE"
        );

        _validateProposalPayload(
            proposalType,
            targetAddress,
            targetValue
        );

        proposalId = proposalCount++;

        Proposal storage p = proposals[proposalId];

        p.proposalType = proposalType;
        p.targetAddress = targetAddress;
        p.targetValue = targetValue;
        p.description = description;
        p.startTime = block.timestamp;
        p.endTime = block.timestamp + votingDuration;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            proposalType,
            targetAddress,
            targetValue,
            description,
            p.startTime,
            p.endTime
        );
    }

    function vote(uint256 proposalId, bool support) external {
        Proposal storage p = _getExistingProposal(proposalId);

        require(block.timestamp >= p.startTime, "VOTING_NOT_STARTED");
        require(block.timestamp < p.endTime, "VOTING_ENDED");
        require(!hasVoted[proposalId][msg.sender], "ALREADY_VOTED");

        uint256 weight = token.balanceOf(msg.sender);

        require(weight > 0, "NO_VOTING_POWER");

        hasVoted[proposalId][msg.sender] = true;

        if (support) {
            p.forVotes += weight;
        } else {
            p.againstVotes += weight;
        }

        emit Voted(proposalId, msg.sender, support, weight);
    }

    function executeProposal(uint256 proposalId) external {
        Proposal storage p = _getExistingProposal(proposalId);

        require(block.timestamp >= p.endTime, "VOTING_NOT_FINISHED");
        require(!p.executed, "PROPOSAL_ALREADY_EXECUTED");

        uint256 totalVotes = p.forVotes + p.againstVotes;

        require(totalVotes >= quorum, "QUORUM_NOT_REACHED");
        require(p.forVotes > p.againstVotes, "PROPOSAL_REJECTED");

        p.executed = true;

        if (p.proposalType == ProposalType.SetStrategy) {
            vault.setStrategy(p.targetAddress);
        } else if (p.proposalType == ProposalType.SetRewardRate) {
            strategy.setRewardRateBps(p.targetValue);
        } else {
            strategy.setPerformanceFeeBps(p.targetValue);
        }

        emit ProposalExecuted(
            proposalId,
            p.proposalType,
            p.targetAddress,
            p.targetValue,
            p.forVotes,
            p.againstVotes
        );
    }

    function getProposal(uint256 proposalId)
        external
        view
        returns (
            ProposalType proposalType,
            address targetAddress,
            uint256 targetValue,
            string memory description,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 startTime,
            uint256 endTime,
            bool executed
        )
    {
        Proposal storage p = _getExistingProposal(proposalId);

        return (
            p.proposalType,
            p.targetAddress,
            p.targetValue,
            p.description,
            p.forVotes,
            p.againstVotes,
            p.startTime,
            p.endTime,
            p.executed
        );
    }

    function _validateProposalPayload(
        ProposalType proposalType,
        address targetAddress,
        uint256 targetValue
    ) internal pure {
        if (proposalType == ProposalType.SetStrategy) {
            require(
                targetAddress != address(0),
                "ZERO_TARGET_ADDRESS"
            );
            require(
                targetValue == 0,
                "UNEXPECTED_TARGET_VALUE"
            );

            return;
        }

        require(
            targetAddress == address(0),
            "UNEXPECTED_TARGET_ADDRESS"
        );

        if (proposalType == ProposalType.SetRewardRate) {
            require(targetValue <= 2_000, "REWARD_RATE_TOO_HIGH");

            return;
        }

        require(targetValue <= 2_000, "FEE_TOO_HIGH");
    }

    function _getExistingProposal(
        uint256 proposalId
    ) internal view returns (Proposal storage p) {
        require(proposalId < proposalCount, "PROPOSAL_NOT_FOUND");

        p = proposals[proposalId];
    }
}

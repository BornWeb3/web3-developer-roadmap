// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
interface IToken {
    function balanceOf(address account) external view returns (uint256);
}
contract Governance {
    struct Proposal {
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
    }
    IToken public immutable token;
    uint256 public immutable proposalThreshold;
    uint256 public immutable quorum;
    uint256 public immutable votingDuration;
    uint256 public proposalCount;
    mapping(uint256 => Proposal) private proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
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
        uint256 forVotes,
        uint256 againstVotes
    );
    constructor(
        address tokenAddress,
        uint256 creationThreshold,
        uint256 minQuorum,
        uint256 durationSeconds
    ) {
        require(tokenAddress != address(0), "ZERO_TOKEN");
        require(durationSeconds > 0, "ZERO_DURATION");
        token = IToken(tokenAddress);
        proposalThreshold = creationThreshold;
        quorum = minQuorum;
        votingDuration = durationSeconds;
    }
    function createProposal(string calldata description)
        external
        returns (uint256 proposalId)
    {
        require(bytes(description).length > 0, "EMPTY_DESCRIPTION");
        require(
            token.balanceOf(msg.sender) >= proposalThreshold,
            "INSUFFICIENT_POWER_TO_PROPOSE"
        );
        proposalId = proposalCount;
        proposalCount += 1;
        Proposal storage p = proposals[proposalId];
        p.description = description;
        p.startTime = block.timestamp;
        p.endTime = block.timestamp + votingDuration;
        emit ProposalCreated(
            proposalId,
            msg.sender,
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
        emit ProposalExecuted(
            proposalId,
            p.forVotes,
            p.againstVotes
        );
    }
    function getProposal(uint256 proposalId)
        external
        view
        returns (
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
            p.description,
            p.forVotes,
            p.againstVotes,
            p.startTime,
            p.endTime,
            p.executed
        );
    }
    function proposalPassed(uint256 proposalId)
        external
        view
        returns (bool)
    {
        Proposal storage p = _getExistingProposal(proposalId);
        if (block.timestamp < p.endTime) {
            return false;
        }
        uint256 totalVotes = p.forVotes + p.againstVotes;
        return totalVotes >= quorum && p.forVotes > p.againstVotes;
    }
    function _getExistingProposal(uint256 proposalId)
        internal
        view
        returns (Proposal storage p)
    {
        require(proposalId < proposalCount, "PROPOSAL_NOT_FOUND");
        p = proposals[proposalId];
    }
}

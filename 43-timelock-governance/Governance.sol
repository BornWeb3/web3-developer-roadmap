// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IConfig {
    function setFee(uint256 newFee) external;
    function setMaxUsers(uint256 newMax) external;
    function setPaused(bool status) external;
}

contract Governance {
    enum ProposalType {
        SetFee,
        SetMaxUsers,
        SetPaused
    }

    struct Proposal {
        ProposalType proposalType;
        uint256 value;
        bool executed;
        uint256 approvals;
        uint256 deadline;
    }

    address public owner;
    IConfig public config;

    uint256 public proposalCount;
    uint256 public constant VOTING_DURATION = 3 days;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public voted;

    event ProposalCreated(
        uint256 indexed proposalId,
        ProposalType proposalType,
        uint256 value,
        uint256 deadline
    );

    event Voted(
        uint256 indexed proposalId,
        address indexed voter
    );

    event ProposalExecuted(uint256 indexed proposalId);

    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY_OWNER");
        _;
    }

    constructor(address configAddress) {
        require(configAddress != address(0), "ZERO_CONFIG");

        owner = msg.sender;
        config = IConfig(configAddress);
    }

    function createProposal(
        ProposalType proposalType,
        uint256 value
    ) external onlyOwner {
        proposalCount++;

        proposals[proposalCount] = Proposal({
            proposalType: proposalType,
            value: value,
            executed: false,
            approvals: 0,
            deadline: block.timestamp + VOTING_DURATION
        });

        emit ProposalCreated(
            proposalCount,
            proposalType,
            value,
            block.timestamp + VOTING_DURATION
        );
    }

    function vote(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp < proposal.deadline, "VOTING_ENDED");
        require(!voted[proposalId][msg.sender], "ALREADY_VOTED");

        voted[proposalId][msg.sender] = true;
        proposal.approvals++;

        emit Voted(proposalId, msg.sender);
    }

    function executeProposal(uint256 proposalId) external onlyOwner {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp >= proposal.deadline, "VOTING_ACTIVE");
        require(!proposal.executed, "ALREADY_EXECUTED");
        require(proposal.approvals > 0, "NO_APPROVALS");

        proposal.executed = true;

        if (proposal.proposalType == ProposalType.SetFee) {
            config.setFee(proposal.value);
        } else if (proposal.proposalType == ProposalType.SetMaxUsers) {
            config.setMaxUsers(proposal.value);
        } else if (proposal.proposalType == ProposalType.SetPaused) {
            config.setPaused(proposal.value == 1);
        }

        emit ProposalExecuted(proposalId);
    }
}

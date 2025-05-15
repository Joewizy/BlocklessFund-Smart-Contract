// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FundNgn is Ownable {
    IERC20 public cNGN;

    // Errors
    error FundNgn__AmountMustBeGreaterThanZero();
    error FundNgn__DurationMustBeGreaterThanZer0();
    error FundNgn__CampaignHasEnded();
    error FundNgn__OnlyCreatorCanWithdraw();
    error FundNgn__FundHaveAlreadyBeenWithdrawn();
    error FundNgn__ProposalAlreadyExists();
    error FundNgn__NotEnoughVotes();
    error FundNgn__VotingHasEnded();
    error FundNgn__AlreadyVoted();
    error FundNgn__NotWhitelisted();

    uint256 private constant PRECISION = 1e18; // erc20 token has 18 decimals
    uint256 private constant VOTING_PERIOD = 7 days;

    uint256 private campaignCount = 1;
    uint256 private proposalCount = 1;

    struct Campaign {
        uint256 id;
        address creator;
        string title;
        string description;
        uint256 goal;
        uint256 startTime;
        uint256 deadline;
        uint256 amountRaised;
        bool completed;
    }

    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        uint256 goal;
        uint256 startTime;
        uint256 deadline;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
        bool active;
    }

    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => uint256)) public donations;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public votes;
    mapping(address => bool) public whitelisted;

    event CampaignCreated(
        uint256 indexed id, address indexed creator, string title, uint256 goal, uint256 startTime, uint256 deadline
    );

    event DonationReceived(uint256 indexed campaignId, address indexed donor, uint256 amount);

    event FundsWithdrawn(uint256 indexed campaignId, uint256 amount);

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        uint256 goal,
        uint256 startTime,
        uint256 deadline
    );

    event VotedOnProposal(uint256 indexed proposalId, address indexed voter, bool inFavor);

    event ProposalExecuted(uint256 indexed proposalId);

    constructor(address _cNGNAddress) Ownable(msg.sender) {
        cNGN = IERC20(_cNGNAddress);
        whitelisted[msg.sender] = true;
    }

    function createCampaign(string memory _title, string memory _description, uint256 _goal, uint256 _durationInSeconds)
        external
    {
        if (!whitelisted[msg.sender]) {
            revert FundNgn__NotWhitelisted();
        }
        if (_goal == 0) {
            revert FundNgn__AmountMustBeGreaterThanZero();
        }
        if (_durationInSeconds == 0) {
            revert FundNgn__DurationMustBeGreaterThanZer0();
        }

        uint256 startTime = block.timestamp;
        uint256 campaignId = campaignCount++;
        uint256 deadline = block.timestamp + _durationInSeconds;

        campaigns[campaignId] = Campaign({
            id: campaignId,
            creator: msg.sender,
            title: _title,
            description: _description,
            goal: _goal,
            startTime: startTime,
            deadline: deadline,
            amountRaised: 0,
            completed: false
        });

        emit CampaignCreated(campaignId, msg.sender, _title, _goal, startTime, deadline);
    }

    function donate(uint256 _campaignId, uint256 _amount) external {
        Campaign storage campaign = campaigns[_campaignId];
        if (block.timestamp >= campaign.deadline) {
            revert FundNgn__CampaignHasEnded();
        }
        if (_amount <= 0) {
            revert FundNgn__AmountMustBeGreaterThanZero();
        }

        campaign.amountRaised += _amount;
        donations[_campaignId][msg.sender] += _amount;

        cNGN.transferFrom(msg.sender, address(this), _amount);

        emit DonationReceived(_campaignId, msg.sender, _amount);
    }

    function withdrawFunds(uint256 _campaignId) external {
        Campaign storage campaign = campaigns[_campaignId];

        if (msg.sender != campaign.creator) {
            revert FundNgn__OnlyCreatorCanWithdraw();
        }
        if (block.timestamp < campaign.deadline) {
            revert FundNgn__CampaignHasEnded();
        }
        if (campaign.completed) {
            revert FundNgn__FundHaveAlreadyBeenWithdrawn();
        }

        campaign.completed = true;

        cNGN.transfer(campaign.creator, campaign.amountRaised);

        emit FundsWithdrawn(_campaignId, campaign.amountRaised);
    }

    function createProposal(string memory _title, string memory _description, uint256 _goal) external {
        uint256 startTime = block.timestamp;
        uint256 proposalId = proposalCount++;
        uint256 deadline = block.timestamp + VOTING_PERIOD;

        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            title: _title,
            description: _description,
            goal: _goal,
            startTime: startTime,
            deadline: deadline,
            votesFor: 0,
            votesAgainst: 0,
            executed: false,
            active: true
        });

        emit ProposalCreated(proposalId, msg.sender, _title, _goal, startTime, deadline);
    }

    function voteOnProposal(uint256 _proposalId, bool _voteFor) external {
        Proposal storage proposal = proposals[_proposalId];

        if (block.timestamp >= proposal.deadline) {
            revert FundNgn__VotingHasEnded();
        }

        if (votes[_proposalId][msg.sender]) {
            revert FundNgn__AlreadyVoted();
        }

        uint256 voteWeight = _getTieredVoteWeight(msg.sender);

        if (_voteFor) {
            proposal.votesFor += voteWeight;
        } else {
            proposal.votesAgainst += voteWeight;
        }

        votes[_proposalId][msg.sender] = true;

        emit VotedOnProposal(_proposalId, msg.sender, _voteFor);
    }

    function executeProposal(uint256 _proposalId) external {
        uint256 startTime = block.timestamp;
        Proposal storage proposal = proposals[_proposalId];

        if (block.timestamp < proposal.deadline) {
            revert FundNgn__VotingHasEnded();
        }

        if (proposal.votesFor <= proposal.votesAgainst) {
            revert FundNgn__NotEnoughVotes();
        }

        if (proposal.executed) {
            revert FundNgn__ProposalAlreadyExists();
        }

        proposal.executed = true;
        uint256 campaignId = campaignCount++;
        uint256 deadline = block.timestamp + (proposal.deadline - proposal.startTime);

        campaigns[campaignId] = Campaign({
            id: campaignId,
            creator: proposal.proposer,
            title: proposal.title,
            description: proposal.description,
            goal: proposal.goal,
            startTime: startTime,
            deadline: deadline,
            amountRaised: 0,
            completed: false
        });

        emit CampaignCreated(campaignId, proposal.proposer, proposal.title, proposal.goal, startTime, deadline);
        emit ProposalExecuted(_proposalId);
    }

    // Whitelist Management
    function addToWhitelist(address _address) external onlyOwner {
        whitelisted[_address] = true;
    }

    function removeFromWhitelist(address _address) external onlyOwner {
        whitelisted[_address] = false;
    }

    // View Functions
    function _getTieredVoteWeight(address voter) internal view returns (uint256) {
        uint256 balance = cNGN.balanceOf(voter);

        if (balance >= 10_000 * PRECISION) {
            return 10;
        } else if (balance >= 1_000 * PRECISION) {
            return 5;
        } else if (balance >= 1 * PRECISION) {
            return 1;
        } else {
            return 0;
        }
    }

    // Getter Functions
    function getCampaign(uint256 _campaignId) external view returns (Campaign memory) {
        return campaigns[_campaignId];
    }

    function getProposal(uint256 _proposalId) external view returns (Proposal memory) {
        return proposals[_proposalId];
    }

    function getDonationAmount(uint256 campaignId, address donator) external view returns (uint256) {
        return donations[campaignId][donator];
    }

    function getVoteWeight(address voter) external view returns (uint256) {
        return _getTieredVoteWeight(voter);
    }

    function getCampaignCounts() external view returns (uint256) {
        return campaignCount;
    }

    function getProposalCounts() external view returns (uint256) {
        return proposalCount;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { FundNgn } from "../src/FundNgn.sol";
import { MockCNGN } from "./mocks/MockCNGN.sol";

contract FundNgnTest is Test {
    FundNgn public fundNgn;
    MockCNGN mockCGN;

    address public USER = makeAddr("user");
    address public CREATOR = makeAddr("creator");
    address public VOTER1 = makeAddr("voter1");
    address public VOTER2 = makeAddr("voter2");
    address public WHALE = makeAddr("whale");

    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 10**18; // 100 million cNGN tokens
    uint256 public constant INITIAL_BALANCE = 10_000 * 10**18; 
    uint256 public constant CAMPAIGN_GOAL = 500 * 10**18;
    uint256 public constant CAMPAIGN_DURATION = 5 days;
    uint256 public constant VOTING_PERIOD = 7 days;

    function setUp() public {
        mockCGN = new MockCNGN("cNGN", "cNGN", INITIAL_SUPPLY);
        fundNgn = new FundNgn(address(mockCGN));
        
        mockCGN.mint(USER, INITIAL_BALANCE);
        mockCGN.mint(CREATOR, INITIAL_BALANCE);
        mockCGN.mint(VOTER1, INITIAL_BALANCE);
        mockCGN.mint(VOTER2, INITIAL_BALANCE);
        mockCGN.mint(WHALE, 1_000 * 10**18); // votes would be 5
    }

    function testCreateCampaign() public {
        // Whitelist CREATOR as the deployer (owner)
        fundNgn.addToWhitelist(CREATOR);

        vm.startPrank(CREATOR);

        string memory _title = "Youth Empowerment";
        string memory _description = "To empower youth with resources";
        
        vm.expectEmit(true, true, true, true);
        emit FundNgn.CampaignCreated(1, CREATOR, _title, CAMPAIGN_GOAL, block.timestamp, block.timestamp + CAMPAIGN_DURATION);
        
        fundNgn.createCampaign(_title, _description, CAMPAIGN_GOAL, CAMPAIGN_DURATION);
        
        FundNgn.Campaign memory campaign = fundNgn.getCampaign(1);
        
        assertEq(campaign.id, 1);
        assertEq(campaign.creator, CREATOR);
        assertEq(campaign.title, _title);
        assertEq(campaign.description, _description);
        assertEq(campaign.goal, CAMPAIGN_GOAL);
        assertGt(campaign.startTime, 0);
        assertEq(campaign.deadline, campaign.startTime + CAMPAIGN_DURATION);
        assertEq(campaign.amountRaised, 0);
        assertEq(campaign.completed, false);
    }

    function testCreateCampaignRevertsWhenNotWhitelisted() public {
        vm.startPrank(CREATOR);
        vm.expectRevert(FundNgn.FundNgn__NotWhitelisted.selector);
        fundNgn.createCampaign("Title", "Description", CAMPAIGN_GOAL, CAMPAIGN_DURATION);
    }

    function testCreateCampaignRevertsWithInvalidGoal() public {
        // Whitelist CREATOR
        fundNgn.addToWhitelist(CREATOR);

        vm.startPrank(CREATOR);
        
        vm.expectRevert(FundNgn.FundNgn__AmountMustBeGreaterThanZero.selector);
        fundNgn.createCampaign("Title", "Description", 0, CAMPAIGN_DURATION);
    }

    function testCreateCampaignRevertsWithInvalidDuration() public {
        // Whitelist CREATOR
        fundNgn.addToWhitelist(CREATOR);

        vm.startPrank(CREATOR);
        
        vm.expectRevert(FundNgn.FundNgn__DurationMustBeGreaterThanZer0.selector);
        fundNgn.createCampaign("Title", "Description", CAMPAIGN_GOAL, 0);
    }

    function testDonateToCampaign() public {
        fundNgn.addToWhitelist(CREATOR);

        vm.startPrank(CREATOR);
        uint256 donatedAmount = 100 * 10**18; // 100 cNGN

        string memory _title = "Youth Empowerment";
        string memory _description = "To empower youth with resources";
        
        fundNgn.createCampaign(_title, _description, CAMPAIGN_GOAL, CAMPAIGN_DURATION);
        vm.stopPrank();

        vm.startPrank(USER);
        uint256 userStartBalance = mockCGN.balanceOf(USER);

        mockCGN.approve(address(fundNgn), donatedAmount); // approved 100cNGN tokens
        
        vm.expectEmit(true, true, true, true);
        emit FundNgn.DonationReceived(1, USER, donatedAmount);
        
        fundNgn.donate(1, donatedAmount);
        FundNgn.Campaign memory campaign = fundNgn.getCampaign(1);

        uint256 expectedBalance = userStartBalance - donatedAmount;

        assertEq(mockCGN.balanceOf(USER), expectedBalance);
        assertEq(campaign.amountRaised, donatedAmount);
        assertEq(fundNgn.getDonationAmount(1, USER), donatedAmount);
    }

    function testDonateRevertsWhenCampaignHasEnded() public {
        fundNgn.addToWhitelist(CREATOR);

        vm.startPrank(CREATOR);
        fundNgn.createCampaign("Title", "Description", CAMPAIGN_GOAL, CAMPAIGN_DURATION);
        vm.stopPrank();

        // Simulate time passing beyond campaign deadline
        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);

        vm.startPrank(USER);
        mockCGN.approve(address(fundNgn), 100 * 10**18);
        
        vm.expectRevert(FundNgn.FundNgn__CampaignHasEnded.selector);
        fundNgn.donate(1, 100 * 10**18);
    }

    function testWithdrawCampaignFunds() public {
        // Whitelist CREATOR
        fundNgn.addToWhitelist(CREATOR);

        vm.startPrank(CREATOR);
        string memory _title = "Youth Empowerment";
        string memory _description = "To empower youth with resources";
        
        fundNgn.createCampaign(_title, _description, CAMPAIGN_GOAL, CAMPAIGN_DURATION);
        vm.stopPrank();

        vm.startPrank(USER);
        uint256 userStartBalance = mockCGN.balanceOf(USER);

        mockCGN.approve(address(fundNgn), CAMPAIGN_GOAL); 
        fundNgn.donate(1, CAMPAIGN_GOAL);
        vm.stopPrank();

        // Simulate 5 days
        vm.warp(block.timestamp + CAMPAIGN_DURATION);

        vm.startPrank(CREATOR);
        uint256 creatorStartBalance = mockCGN.balanceOf(CREATOR);
        
        vm.expectEmit(true, true, true, true);
        emit FundNgn.FundsWithdrawn(1, CAMPAIGN_GOAL);
        
        fundNgn.withdrawFunds(1);

        FundNgn.Campaign memory campaign = fundNgn.getCampaign(1);
        uint256 creatorEndBalance = mockCGN.balanceOf(CREATOR);

        assertEq(creatorEndBalance, creatorStartBalance + CAMPAIGN_GOAL);
        assertEq(campaign.amountRaised, CAMPAIGN_GOAL);
        assertEq(campaign.completed, true);
    }

    function testWithdrawRevertsWhenNotCreator() public {
        // Whitelist CREATOR
        fundNgn.addToWhitelist(CREATOR);

        vm.startPrank(CREATOR);
        fundNgn.createCampaign("Title", "Description", CAMPAIGN_GOAL, CAMPAIGN_DURATION);
        vm.stopPrank();

        vm.warp(block.timestamp + CAMPAIGN_DURATION);

        vm.startPrank(USER);
        vm.expectRevert(FundNgn.FundNgn__OnlyCreatorCanWithdraw.selector);
        fundNgn.withdrawFunds(1);
    }

    function testCreateProposal() public {
        vm.startPrank(CREATOR);
        string memory _title = "New Campaign Proposal";
        string memory _description = "Proposal for a new fundraising campaign";
        uint256 _goal = CAMPAIGN_GOAL;

        vm.expectEmit(true, true, true, true);
        emit FundNgn.ProposalCreated(1, CREATOR, _title, _goal, block.timestamp, block.timestamp + VOTING_PERIOD);

        fundNgn.createProposal(_title, _description, _goal);

        FundNgn.Proposal memory proposal = fundNgn.getProposal(1);

        assertEq(proposal.id, 1);
        assertEq(proposal.proposer, CREATOR);
        assertEq(proposal.title, _title);
        assertEq(proposal.description, _description);
        assertEq(proposal.goal, _goal);
        assertGt(proposal.startTime, 0);
        assertEq(proposal.deadline, proposal.startTime + VOTING_PERIOD);
        assertEq(proposal.votesFor, 0);
        assertEq(proposal.votesAgainst, 0);
        assertEq(proposal.executed, false);
        assertEq(proposal.active, true);
    }

    function testVoteOnProposal() public {
        vm.startPrank(CREATOR);
        fundNgn.createProposal("Title", "Description", CAMPAIGN_GOAL);
        vm.stopPrank();

        vm.startPrank(VOTER1);
        vm.expectEmit(true, true, true, true);
        emit FundNgn.VotedOnProposal(1, VOTER1, true);
        fundNgn.voteOnProposal(1, true);
        vm.stopPrank();

        FundNgn.Proposal memory proposal = fundNgn.getProposal(1);
        assertEq(proposal.votesFor, 10); // Voter1 has full balance (10 vote weight)
    }

    function testVoteRevertsWhenAlreadyVoted() public {
        vm.startPrank(CREATOR);
        fundNgn.createProposal("Title", "Description", CAMPAIGN_GOAL);
        vm.stopPrank();

        vm.startPrank(VOTER1);
        fundNgn.voteOnProposal(1, true);

        vm.expectRevert(FundNgn.FundNgn__AlreadyVoted.selector);
        fundNgn.voteOnProposal(1, false);
    }

    function testExecuteProposal() public {
        // Whitelist CREATOR for campaign creation during execution
        fundNgn.addToWhitelist(CREATOR);

        vm.startPrank(CREATOR);
        fundNgn.createProposal("New Campaign", "Campaign Description", CAMPAIGN_GOAL);
        vm.stopPrank();

        vm.startPrank(VOTER1);
        fundNgn.voteOnProposal(1, true);
        vm.stopPrank();

        vm.warp(block.timestamp + VOTING_PERIOD + 1);

        vm.startPrank(CREATOR);
        vm.expectEmit(true, true, true, true);
        emit FundNgn.ProposalExecuted(1);
        emit FundNgn.CampaignCreated(1, CREATOR, "New Campaign", CAMPAIGN_GOAL, block.timestamp, block.timestamp + VOTING_PERIOD);

        fundNgn.executeProposal(1);

        FundNgn.Proposal memory proposal = fundNgn.getProposal(1);
        FundNgn.Campaign memory campaign = fundNgn.getCampaign(1);

        assertTrue(proposal.executed);
        assertEq(campaign.title, "New Campaign");
        assertEq(campaign.creator, CREATOR);
    }

    function testExecuteProposalRevertsWhenNotEnoughVotes() public {
        vm.startPrank(CREATOR);
        fundNgn.createProposal("New Campaign", "Campaign Description", CAMPAIGN_GOAL);
        vm.stopPrank();

        vm.startPrank(VOTER1);
        fundNgn.voteOnProposal(1, false);
        vm.stopPrank();

        vm.warp(block.timestamp + VOTING_PERIOD + 1);

        vm.startPrank(CREATOR);
        vm.expectRevert(FundNgn.FundNgn__NotEnoughVotes.selector);
        fundNgn.executeProposal(1);
    }

    function testProposalVotesIsRight() public {
        vm.startPrank(CREATOR);
        fundNgn.createProposal("New Campaign", "Campaign Description", CAMPAIGN_GOAL);
        vm.stopPrank();

        vm.startPrank(VOTER1);
        fundNgn.voteOnProposal(1, true);
        vm.stopPrank();

        vm.startPrank(VOTER2);
        fundNgn.voteOnProposal(1, true);
        vm.stopPrank();

        vm.startPrank(WHALE);
        fundNgn.voteOnProposal(1, false);
        vm.stopPrank();

        vm.warp(block.timestamp + VOTING_PERIOD + 1);   
        
        uint256 expectVoteOneAndTwoVoteWeight = 10;
        uint256 expectedWhaleVoteWeight = 5;

        assertEq(expectedWhaleVoteWeight, fundNgn.getVoteWeight(WHALE));
        assertEq(expectVoteOneAndTwoVoteWeight, fundNgn.getVoteWeight(VOTER1));
        assertEq(expectVoteOneAndTwoVoteWeight, fundNgn.getVoteWeight(VOTER2));
    }
}
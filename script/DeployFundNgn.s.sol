// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { FundNgn } from "../src/FundNgn.sol";
import { MockCNGN } from "../test/mocks/MockCNGN.sol";

contract DeployFundNgn is Script {
    address public mockCNGNAddress;
    address public fundNgnAddress;

    function run() external {
        vm.startBroadcast();

        // Deploy the MockCNGN (mockCGN) contract
        MockCNGN mockCNGN = new MockCNGN(
            "cNGN",             
            "cNGN",             
            100_000_000 * 10**18 // Initial supply: 100 million tokens
        );
        mockCNGNAddress = address(mockCNGN);
        console.log("cNGN Mock contract deployed:", mockCNGNAddress);

        FundNgn fundNgn = new FundNgn(mockCNGNAddress);
        fundNgnAddress = address(fundNgn);
        console.log("Crowdfunding contract deployed:", fundNgnAddress);

        vm.stopBroadcast();

        verifyDeployment();
    }

    function verifyDeployment() internal view {
        require(mockCNGNAddress != address(0), "MockCNGN not deployed");
        require(fundNgnAddress != address(0), "FundNgn not deployed");
        console.log("All deployments successful.");
        console.log("MockCNGN address:", mockCNGNAddress);
        console.log("FundNgn address:", fundNgnAddress);
        console.log("To verify contracts on a block explorer, use the following commands:");
        console.log(
            "forge verify-contract --chain-id %d --constructor-args $(cast abi-encode \"constructor(string,string,uint256)\" \"cNGN\" \"cNGN\" 100000000000000000000000000) %s MockCNGN",
            block.chainid,
            mockCNGNAddress
        );
        console.log(
            "forge verify-contract --chain-id %d --constructor-args $(cast abi-encode \"constructor(address)\" %s) %s FundNgn",
            block.chainid,
            mockCNGNAddress,
            fundNgnAddress
        );
    }
}

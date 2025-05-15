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

//   cNGN Mock contract deployed: 0xfa2E05678f71859848812Fc28a3C11570dE7cF6b
//   Crowdfunding contract deployed: 0xcDb5e4C288853E4DFdFB058d3dC52A59a417B710
//   cNGN Mock contract deployed: 0x7FfebfF3C6a3ADBA55006cAF15be69b1e17bc659
//   Crowdfunding contract deployed: 0xf25373Ab7c2a68BBC5271fdbd728C6FAc6c1fa0A

// deployed:
//   cNGN Mock contract deployed: 0x793c2f578926872366eA6aB416e0153Fa33aa56E
//   Crowdfunding contract deployed: 0xf43237F67F5d1e1d0E9D92e2904f218E0b2553C3
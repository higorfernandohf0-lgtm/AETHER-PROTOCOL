// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AetherGovernor} from "../src/governance/AetherGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract DeployGovernor is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Endereços já deployados
        address tokenAddress = 0xB6127998eb92e233DBC25C008b788e174BAE8d5F;
        address timelockAddress = 0x36b4d40384e974d3067050111cfB5F823FCBf1Ed;

        vm.startBroadcast(deployerPrivateKey);

        AetherGovernor governor = new AetherGovernor(
            IVotes(tokenAddress),
            TimelockController(payable(timelockAddress))
        );

        console.log("AetherGovernor deployed at:", address(governor));

        vm.stopBroadcast();
    }
}
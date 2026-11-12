// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AetherToken} from "../src/governance/AetherToken.sol";
import {AetherGovernor} from "../src/governance/AetherGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract DeployGovernance is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        AetherToken token = new AetherToken(deployer);
        console.log("AetherToken deployed at:", address(token));

        address[] memory emptyArray;
        TimelockController timelock = new TimelockController(
            2 days,
            emptyArray,
            emptyArray,
            deployer
        );
        console.log("TimelockController deployed at:", address(timelock));

        AetherGovernor governor = new AetherGovernor(
            IVotes(address(token)),
            timelock
        );
        console.log("AetherGovernor deployed at:", address(governor));

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(governor));
        timelock.renounceRole(adminRole, deployer);

        vm.stopBroadcast();
    }
}
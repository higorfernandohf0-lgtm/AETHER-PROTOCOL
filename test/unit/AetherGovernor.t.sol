// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AetherToken} from "../../src/governance/AetherToken.sol";
import {AetherGovernor} from "../../src/governance/AetherGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract AetherGovernorTest is Test {
    AetherToken internal token;
    TimelockController internal timelock;
    AetherGovernor internal governor;

    address internal deployer = makeAddr("deployer");
    address internal voter = makeAddr("voter");

    function setUp() public {
        vm.startPrank(deployer);

        token = new AetherToken(deployer);
        
        address[] memory emptyArray;
        timelock = new TimelockController(2 days, emptyArray, emptyArray, deployer);

        governor = new AetherGovernor(IVotes(address(token)), timelock);

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(governor));
        timelock.renounceRole(adminRole, deployer);

        token.transfer(voter, 10_000_000 ether);
        
        vm.stopPrank();

        vm.prank(voter);
        token.delegate(voter);
        
        // Avança um bloco para garantir que o checkpoint de votos seja registrado
        vm.roll(block.number + 1);
    }

    function test_GovernorCanProposeAndExecute() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Test Proposal";

        targets[0] = address(timelock);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("getMinDelay()");

        // 1. Cria a proposta
        vm.prank(voter);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // 2. Avança BLOCOS para começar a votação (votingDelay = 1 dia em blocos)
        // Como o relógio é block.number, avançamos blocos suficientes.
        // Assumindo 1 bloco por segundo (ou apenas avançando bastante para garantir):
        vm.roll(block.number + 1 days); 
        vm.warp(block.timestamp + 1 days + 1);

        // 3. Vota
        vm.prank(voter);
        governor.castVote(proposalId, 1); // 1 = For

        // 4. Avança BLOCOS para terminar a votação (votingPeriod = 1 semana em blocos)
        vm.roll(block.number + 1 weeks);
        vm.warp(block.timestamp + 1 weeks + 1);

        // 5. Enfileira no Timelock
        governor.queue(targets, values, calldatas, keccak256(bytes(description)));

        // 6. Avança o tempo do Timelock (minDelay = 2 dias, que usa block.timestamp)
        vm.warp(block.timestamp + 2 days + 1);
        vm.roll(block.number + 1);

        // 7. Executa
        governor.execute(targets, values, calldatas, keccak256(bytes(description)));
    }
}
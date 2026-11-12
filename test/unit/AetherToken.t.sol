// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AetherToken} from "../../src/governance/AetherToken.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract AetherTokenTest is Test {
    AetherToken internal token;

    uint256 internal constant TREASURY_PRIVATE_KEY = 0xA11CE;

    address internal treasury;
    address internal delegate1 = makeAddr("delegate1");
    address internal delegate2 = makeAddr("delegate2");
    address internal spender = makeAddr("spender");

    uint256 internal constant INITIAL_SUPPLY = 100_000_000 ether;

    function setUp() public {
        treasury = vm.addr(TREASURY_PRIVATE_KEY);
        token = new AetherToken(treasury);
    }

    function test_TokenNameAndSymbol() public view {
        assertEq(token.name(), "Aether Token");
        assertEq(token.symbol(), "AETH");
    }

    function test_TokenUses18Decimals() public view {
        assertEq(token.decimals(), 18);
    }

    function test_InitialSupplyIs100Million() public view {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    function test_EntireInitialSupplyGoesToTreasury() public view {
        assertEq(token.balanceOf(treasury), INITIAL_SUPPLY);
    }

    function test_RevertWhenTreasuryAddressIsZero() public {
        vm.expectRevert();
        new AetherToken(address(0));
    }

    function test_TokensDoNotHaveVotingPowerBeforeDelegation() public view {
        assertEq(token.getVotes(treasury), 0);
    }

    function test_TreasuryCanDelegateVotesToItself() public {
        vm.prank(treasury);
        token.delegate(treasury);
        assertEq(token.getVotes(treasury), INITIAL_SUPPLY);
    }

    function test_DelegateReceivesVotingPower() public {
        vm.prank(treasury);
        token.delegate(delegate1);
        assertEq(token.getVotes(delegate1), INITIAL_SUPPLY);
    }

    function test_DelegationCanBeChanged() public {
        vm.prank(treasury);
        token.delegate(delegate1);
        vm.prank(treasury);
        token.delegate(delegate2);
        assertEq(token.getVotes(delegate1), 0);
        assertEq(token.getVotes(delegate2), INITIAL_SUPPLY);
    }

    function test_TransferMovesVotingPower() public {
        vm.prank(treasury);
        token.delegate(treasury);

        vm.prank(treasury);
        token.transfer(delegate1, 1_000 ether);

        assertEq(token.getVotes(treasury), INITIAL_SUPPLY - 1_000 ether);
        assertEq(token.getVotes(delegate1), 0);

        vm.prank(delegate1);
        token.delegate(delegate1);
        assertEq(token.getVotes(delegate1), 1_000 ether);
    }

    function test_TotalSupplyRemainsConstantAfterTransfer() public {
        vm.prank(treasury);
        token.transfer(delegate1, 1_000 ether);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    function test_HistoricalVotesAreRecorded() public {
        // Fixa o tempo em 100 para ter controle absoluto
        vm.warp(100);

        vm.prank(treasury);
        token.delegate(treasury);

        // Avança o tempo para 200 (bem depois do tempo da delegação)
        vm.warp(200);

        // Consulta os votos no tempo 100 (que já passou)
        assertEq(token.getPastVotes(treasury, 100), INITIAL_SUPPLY);
    }

    function test_PermitAllowsSignatureBasedApproval() public {
        uint256 deadline = block.timestamp + 1 days;
        uint256 value = 1_000 ether;

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                treasury,
                spender,
                value,
                token.nonces(treasury),
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(TREASURY_PRIVATE_KEY, digest);

        token.permit(treasury, spender, value, deadline, v, r, s);

        assertEq(token.allowance(treasury, spender), value);
    }

    function test_RevertWhenPermitDeadlineHasExpired() public {
        uint256 deadline = block.timestamp - 1;

        vm.expectRevert();
        token.permit(treasury, spender, 1_000 ether, deadline, 27, bytes32(0), bytes32(0));
    }

    function test_RevertWhenPermitSignatureIsInvalid() public {
        uint256 deadline = block.timestamp + 1 days;

        vm.expectRevert(ECDSA.ECDSAInvalidSignature.selector);

        token.permit(
            treasury,
            spender,
            1_000 ether,
            deadline,
            27,
            bytes32(0),
            bytes32(0)
        );
    }
}
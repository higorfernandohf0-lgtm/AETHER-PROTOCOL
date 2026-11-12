// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {AetherVault} from "../../src/vault/AetherVault.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";

contract AetherVaultHandler is Test {
    AetherVault public vault;
    MockUSDC public usdc;

    address[] public actors;

    constructor(AetherVault _vault, MockUSDC _usdc) {
        vault = _vault;
        usdc = _usdc;

        actors.push(makeAddr("actor0"));
        actors.push(makeAddr("actor1"));
        actors.push(makeAddr("actor2"));
    }

    // Deposit USDC and receive vault shares.
    function deposit(uint256 actorSeed, uint256 amount) external {
        address actor = actors[actorSeed % actors.length];

        amount = bound(amount, 1, 1_000_000 * 10 ** 6);

        usdc.mint(actor, amount);

        vm.startPrank(actor);
        usdc.approve(address(vault), amount);
        vault.deposit(amount, actor);
        vm.stopPrank();
    }

    // Redeem vault shares for USDC.
    function redeem(uint256 actorSeed, uint256 shares) external {
        address actor = actors[actorSeed % actors.length];

        uint256 balance = vault.balanceOf(actor);

        if (balance == 0) {
            return;
        }

        shares = bound(shares, 1, balance);

        vm.prank(actor);
        vault.redeem(shares, actor, actor);
    }

    // Transfer vault shares between controlled actors.
    function transferShares(
        uint256 fromSeed,
        uint256 toSeed,
        uint256 shares
    ) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];

        // Ignore transfers to the same actor.
        if (from == to) {
            return;
        }

        uint256 balance = vault.balanceOf(from);

        if (balance == 0) {
            return;
        }

        shares = bound(shares, 1, balance);

        vm.prank(from);
        vault.transfer(to, shares);
    }
}
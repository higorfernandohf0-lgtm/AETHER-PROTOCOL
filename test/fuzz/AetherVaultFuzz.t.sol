
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {AetherVault} from "../../src/vault/AetherVault.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";

contract AetherVaultFuzzTest is Test {
    AetherVault internal vault;
    MockUSDC internal usdc;

    address internal owner = makeAddr("owner");
    address internal user = makeAddr("user");

    function setUp() public {
        usdc = new MockUSDC();

        AetherVault implementation = new AetherVault();

        bytes memory initializationData = abi.encodeCall(
            AetherVault.initialize,
            (usdc, owner)
        );

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initializationData
        );

        vault = AetherVault(address(proxy));
    }

    function testFuzz_DepositEmitsCorrectShares(
        uint256 assets
    ) public {
        assets = bound(assets, 1, 1_000_000 * 10 ** 6);

        usdc.mint(user, assets);

        vm.startPrank(user);
        usdc.approve(address(vault), assets);

        uint256 expectedShares = assets * 1000;
        uint256 receivedShares = vault.deposit(assets, user);

        vm.stopPrank();

        assertEq(receivedShares, expectedShares);
        assertEq(vault.balanceOf(user), expectedShares);
        assertEq(vault.totalAssets(), assets);
    }

    function testFuzz_RedeemReturnsDepositedAssets(
        uint256 assets
    ) public {
        assets = bound(assets, 1, 1_000_000 * 10 ** 6);

        usdc.mint(user, assets);

        vm.startPrank(user);

        usdc.approve(address(vault), assets);

        uint256 shares = vault.deposit(assets, user);

        uint256 recoveredAssets = vault.redeem(
            shares,
            user,
            user
        );

        vm.stopPrank();

        assertEq(recoveredAssets, assets);
        assertEq(vault.balanceOf(user), 0);
        assertEq(usdc.balanceOf(user), assets);
        assertEq(vault.totalAssets(), 0);
    }
}

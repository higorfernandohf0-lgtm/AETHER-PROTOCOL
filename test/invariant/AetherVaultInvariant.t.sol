// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {AetherVault} from "../../src/vault/AetherVault.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {AetherVaultHandler} from "./AetherVaultHandler.sol";

contract AetherVaultInvariantTest is StdInvariant, Test {
    AetherVault internal vault;
    MockUSDC internal usdc;
    AetherVaultHandler internal handler;

    address internal owner = makeAddr("owner");

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

        handler = new AetherVaultHandler(vault, usdc);

        targetContract(address(handler));
    }

    // Invariant 1:
    // Vault accounting matches its actual USDC balance.
    function invariant_TotalAssetsMatchUSDCBalance() public view {
        assertEq(
            vault.totalAssets(),
            usdc.balanceOf(address(vault))
        );
    }

    // Invariant 2:
    // Total supply equals the sum of shares held by all actors.
    function invariant_TotalSupplyMatchesActorBalances() public view {
        uint256 totalActorShares;

        for (uint256 i = 0; i < 3; i++) {
            totalActorShares += vault.balanceOf(handler.actors(i));
        }

        assertEq(vault.totalSupply(), totalActorShares);
    }
}
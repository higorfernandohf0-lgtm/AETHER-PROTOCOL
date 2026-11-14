// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AetherVault} from "../../src/vault/AetherVault.sol";
import {AetherOracleGuard} from "../../src/oracles/AetherOracleGuard.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {MockAggregatorV3} from "../mocks/MockAggregatorV3.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AetherVaultOracleIntegrationTest is Test {
    MockUSDC internal usdc;
    MockAggregatorV3 internal mockFeed;
    AetherOracleGuard internal oracleGuard;
    AetherVault internal vault;

    address internal owner = makeAddr("owner");
    address internal user = makeAddr("user");

    function setUp() public {
        usdc = new MockUSDC();
        
        // 1. Deploy do Mock do Chainlink (preço inicial $1.00 e atualizado agora)
        // USDC tem 8 decimais no Chainlink, então $1.00 = 100000000
        mockFeed = new MockAggregatorV3(100000000, block.timestamp);

        // 2. Deploy do Oracle Guard
        oracleGuard = new AetherOracleGuard(
            address(mockFeed),
            1 hours,        // staleness
            90000000,       // minPrice $0.90
            110000000       // maxPrice $1.10
        );

        // 3. Deploy do Vault
        AetherVault vaultImpl = new AetherVault();
        bytes memory initData = abi.encodeWithSelector(
            AetherVault.initialize.selector,
            address(usdc),
            owner
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(vaultImpl), initData);
        vault = AetherVault(address(proxy));

        // 4. Configurar o Oráculo no Vault
        vm.prank(owner);
        vault.setOracleGuard(address(oracleGuard));

        // 5. Mint e approve
        usdc.mint(user, 1000e6);
        vm.prank(user);
        usdc.approve(address(vault), type(uint256).max);
    }

    function test_DepositSucceedsWhenPriceIsValid() public {
        vm.prank(user);
        vault.deposit(1000e6, user);
        assertEq(vault.totalAssets(), 1000e6);
    }

    function test_RevertWhenPriceIsStale() public {
        // Avança o tempo além do staleness (1 hora)
        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(user);
        vm.expectRevert(); // O Oracle Guard vai reverter com StalePrice
        vault.deposit(1000e6, user);
    }

    function test_RevertWhenPriceIsOutOfBounds() public {
        // Muda o preço para $0.50 (abaixo do minPrice de $0.90)
        mockFeed.setAnswer(50000000, block.timestamp);

        vm.prank(user);
        vm.expectRevert(); // O Oracle Guard vai reverter com PriceOutOfBounds
        vault.deposit(1000e6, user);
    }
}
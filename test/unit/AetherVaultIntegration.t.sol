// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AetherVault} from "../../src/vault/AetherVault.sol";
import {AetherAaveStrategy} from "../../src/strategy/AetherAaveStrategy.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {MockAavePool} from "../mocks/MockAavePool.sol";
import {MockAToken} from "../mocks/MockAToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AetherVaultIntegrationTest is Test {
    MockUSDC internal usdc;
    MockAavePool internal aavePool;
    MockAToken internal aToken;
    AetherAaveStrategy internal strategy;
    AetherVault internal vault;

    address internal owner = makeAddr("owner");
    address internal user = makeAddr("user");

    function setUp() public {
        usdc = new MockUSDC();
        aavePool = new MockAavePool();
        aToken = new MockAToken(address(usdc), address(aavePool));

        // 1. Deploy do Vault
        AetherVault vaultImpl = new AetherVault();
        bytes memory initData = abi.encodeWithSelector(
            AetherVault.initialize.selector,
            address(usdc),
            owner
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(vaultImpl), initData);
        vault = AetherVault(address(proxy));

        // 2. Deploy da Estratégia com o Vault como owner
        strategy = new AetherAaveStrategy(
            address(usdc),
            address(aavePool),
            address(aToken),
            address(vault)
        );

        // 3. Configurar estratégia e limite no Vault
        vm.startPrank(owner);
        vault.setStrategy(address(strategy));
        vault.setAllocationCap(1000e6); // Define o limite para 1000 USDC
        vm.stopPrank();

        // 4. Mint e approve
        usdc.mint(user, 1000e6);
        vm.prank(user);
        usdc.approve(address(vault), type(uint256).max);
    }

    function test_AllocateAndTotalAssets() public {
        vm.prank(user);
        vault.deposit(1000e6, user);
        assertEq(vault.totalAssets(), 1000e6);

        vm.prank(owner);
        vault.allocate(500e6); // Agora funciona porque o cap é 1000e6

        assertEq(usdc.balanceOf(address(vault)), 500e6);
        assertEq(usdc.balanceOf(address(aavePool)), 500e6);
        assertEq(vault.totalAssets(), 1000e6);
    }

    function test_Deallocate() public {
        vm.prank(user);
        vault.deposit(1000e6, user);
        vm.prank(owner);
        vault.allocate(500e6);

        vm.prank(owner);
        vault.deallocate(300e6);

        assertEq(usdc.balanceOf(address(vault)), 800e6);
        assertEq(usdc.balanceOf(address(aavePool)), 200e6);
        assertEq(vault.totalAssets(), 1000e6);
    }

    function test_RevertWhenExceedingCap() public {
        vm.prank(user);
        vault.deposit(1000e6, user);

        // Tenta alocar 1500 USDC, mas o cap é 1000 USDC
        vm.prank(owner);
        vm.expectRevert("Exceeds allocation cap");
        vault.allocate(1500e6);
    }

    function test_EmergencyWithdraw() public {
        vm.prank(user);
        vault.deposit(1000e6, user);
        vm.prank(owner);
        vault.allocate(500e6);

        // Emergência: puxa tudo de volta
        vm.prank(owner);
        vault.emergencyWithdraw();

        assertEq(usdc.balanceOf(address(vault)), 1000e6);
        assertEq(usdc.balanceOf(address(aavePool)), 0);
        assertEq(vault.totalAssets(), 1000e6);
    }
}
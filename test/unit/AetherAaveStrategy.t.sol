// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AetherAaveStrategy} from "../../src/strategy/AetherAaveStrategy.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {MockAavePool} from "../mocks/MockAavePool.sol";
import {MockAToken} from "../mocks/MockAToken.sol";

contract AetherAaveStrategyTest is Test {
    MockUSDC internal usdc;
    MockAavePool internal aavePool;
    MockAToken internal aToken;
    AetherAaveStrategy internal strategy;

    address internal owner = makeAddr("owner");

    function setUp() public {
        usdc = new MockUSDC();
        aavePool = new MockAavePool();
        aToken = new MockAToken(address(usdc), address(aavePool));

        strategy = new AetherAaveStrategy(
            address(usdc),
            address(aavePool),
            address(aToken),
            owner
        );

        // Minta USDC para o owner e aprova a strategy
        usdc.mint(owner, 1000e6); // 1000 USDC
        vm.prank(owner);
        usdc.approve(address(strategy), type(uint256).max);
    }

    function test_SupplyAndWithdraw() public {
        // 1. Owner envia USDC para a strategy
        vm.prank(owner);
        usdc.transfer(address(strategy), 500e6);

        // 2. Owner chama supply
        vm.prank(owner);
        strategy.supply(500e6);

        // 3. Verifica que o saldo do Pool é 500 USDC
        assertEq(usdc.balanceOf(address(aavePool)), 500e6);
        assertEq(strategy.totalAssets(), 500e6);

        // 4. Owner chama withdraw
        vm.prank(owner);
        strategy.withdraw(200e6);

        // 5. Verifica que a strategy recebeu 200 USDC e o Pool tem 300 USDC
        assertEq(usdc.balanceOf(address(strategy)), 200e6);
        assertEq(usdc.balanceOf(address(aavePool)), 300e6);
        assertEq(strategy.totalAssets(), 500e6); // 200 no contrato + 300 no Pool
    }

    function test_TotalAssetsInitiallyZero() public view {
        assertEq(strategy.totalAssets(), 0);
    }
}
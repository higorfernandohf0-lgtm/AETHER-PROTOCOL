// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AetherFlashLoanExecutor} from "../../src/flashloan/AetherFlashLoanExecutor.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {MockAavePool} from "../mocks/MockAavePool.sol";

contract AetherFlashLoanExecutorTest is Test {
    MockUSDC internal usdc;
    MockAavePool internal aavePool;
    AetherFlashLoanExecutor internal executor;

    address internal owner = makeAddr("owner");

    function setUp() public {
        usdc = new MockUSDC();
        aavePool = new MockAavePool();
        executor = new AetherFlashLoanExecutor(address(aavePool), owner);

        // O Pool precisa ter USDC para emprestar
        usdc.mint(address(aavePool), 1000e6);

        // O executor precisa aprovar o Pool para devolver o empréstimo
        vm.prank(owner);
        usdc.approve(address(executor), type(uint256).max);
    }

    function test_FlashLoanExecutesSuccessfully() public {
        // O owner chama requestFlashLoan (o executor pega emprestado e devolve)
        vm.prank(owner);
        executor.requestFlashLoan(address(usdc), 500e6, "");

        // Verifica que o Pool recuperou o valor (500e6) e o executor não ficou com saldo
        assertEq(usdc.balanceOf(address(aavePool)), 1000e6); // voltou ao total inicial
        assertEq(usdc.balanceOf(address(executor)), 0);
    }
}
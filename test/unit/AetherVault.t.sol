
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {AetherVault} from "../../src/vault/AetherVault.sol";
import {AetherVaultV2} from "../../src/vault/AetherVaultV2.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";

contract AetherVaultTest is Test {
    AetherVault internal vault;
    MockUSDC internal usdc;

    address internal owner = makeAddr("owner");
    address internal attacker = makeAddr("attacker");

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

    // Initialization tests

    function test_InitializesVaultThroughProxy() public view {
        assertEq(vault.asset(), address(usdc));
        assertEq(vault.owner(), owner);
        assertEq(vault.name(), "Aether USDC Vault");
        assertEq(vault.symbol(), "aUSDC");
        assertEq(vault.decimals(), 9);
        assertFalse(vault.paused());
    }

    function test_RevertWhenInitializingImplementationDirectly() public {
        AetherVault implementation = new AetherVault();

        vm.expectRevert(Initializable.InvalidInitialization.selector);

        implementation.initialize(usdc, attacker);
    }

    function test_RevertWhenInitializingWithZeroUSDC() public {
        AetherVault implementation = new AetherVault();

        bytes memory initializationData = abi.encodeCall(
            AetherVault.initialize,
            (MockUSDC(address(0)), owner)
        );

        vm.expectRevert(bytes("Invalid USDC"));

        new ERC1967Proxy(address(implementation), initializationData);
    }

    function test_RevertWhenInitializingWithZeroOwner() public {
        AetherVault implementation = new AetherVault();

        bytes memory initializationData = abi.encodeCall(
            AetherVault.initialize,
            (usdc, address(0))
        );

        vm.expectRevert(bytes("Invalid owner"));

        new ERC1967Proxy(address(implementation), initializationData);
    }

    // ERC-4626 deposit, mint, withdrawal and redemption tests

    function test_DepositUSDCReceivesShares() public {
        address user = makeAddr("user");
        uint256 depositAmount = 100 * 10 ** 6;

        usdc.mint(user, depositAmount);

        vm.startPrank(user);
        usdc.approve(address(vault), depositAmount);

        uint256 shares = vault.deposit(depositAmount, user);

        vm.stopPrank();

        assertEq(shares, depositAmount * 1000);
        assertEq(vault.balanceOf(user), depositAmount * 1000);
        assertEq(usdc.balanceOf(address(vault)), depositAmount);
    }

    function test_MintSharesReceivesExactShareAmount() public {
        address user = makeAddr("mintUser");

        uint256 requestedShares = 100 * 10 ** 9;
        uint256 expectedAssets = 100 * 10 ** 6;

        usdc.mint(user, expectedAssets);

        vm.startPrank(user);
        usdc.approve(address(vault), expectedAssets);

        uint256 assetsPaid = vault.mint(requestedShares, user);

        vm.stopPrank();

        assertEq(assetsPaid, expectedAssets);
        assertEq(vault.balanceOf(user), requestedShares);
        assertEq(vault.totalAssets(), expectedAssets);
        assertEq(usdc.balanceOf(address(vault)), expectedAssets);
    }

    function test_WithdrawExactUSDCAssets() public {
        address user = makeAddr("withdrawUser");

        uint256 depositAmount = 100 * 10 ** 6;
        uint256 withdrawalAmount = 40 * 10 ** 6;

        usdc.mint(user, depositAmount);

        vm.startPrank(user);
        usdc.approve(address(vault), depositAmount);

        vault.deposit(depositAmount, user);

        uint256 sharesBefore = vault.balanceOf(user);

        uint256 sharesBurned = vault.withdraw(
            withdrawalAmount,
            user,
            user
        );

        vm.stopPrank();

        assertEq(usdc.balanceOf(user), withdrawalAmount);
        assertEq(
            usdc.balanceOf(address(vault)),
            depositAmount - withdrawalAmount
        );
        assertEq(
            vault.balanceOf(user),
            sharesBefore - sharesBurned
        );
        assertEq(
            vault.totalAssets(),
            depositAmount - withdrawalAmount
        );
    }

    function test_RedeemSharesReturnsUSDC() public {
        address user = makeAddr("user");
        uint256 depositAmount = 100 * 10 ** 6;

        usdc.mint(user, depositAmount);

        vm.startPrank(user);
        usdc.approve(address(vault), depositAmount);

        uint256 shares = vault.deposit(depositAmount, user);
        uint256 assets = vault.redeem(shares, user, user);

        vm.stopPrank();

        assertEq(assets, depositAmount);
        assertEq(usdc.balanceOf(user), depositAmount);
        assertEq(vault.balanceOf(user), 0);
        assertEq(usdc.balanceOf(address(vault)), 0);
    }

    function test_RedeemRemainsAvailableWhilePaused() public {
        address user = makeAddr("user");
        uint256 amount = 100 * 10 ** 6;

        usdc.mint(user, amount);

        vm.startPrank(user);
        usdc.approve(address(vault), amount);

        uint256 shares = vault.deposit(amount, user);

        vm.stopPrank();

        vm.prank(owner);
        vault.pause();

        vm.prank(user);
        uint256 assets = vault.redeem(shares, user, user);

        assertEq(assets, amount);
        assertEq(vault.balanceOf(user), 0);
        assertEq(usdc.balanceOf(user), amount);
    }

    // ERC-4626 conversion and preview tests

    function test_ConvertToSharesUsesVaultExchangeRate() public {
        address user = makeAddr("conversionUser");

        uint256 depositAmount = 100 * 10 ** 6;
        uint256 conversionAmount = 25 * 10 ** 6;

        usdc.mint(user, depositAmount);

        vm.startPrank(user);
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user);
        vm.stopPrank();

        uint256 shares = vault.convertToShares(conversionAmount);

        assertEq(shares, conversionAmount * 1000);
    }

    function test_ConvertToAssetsUsesVaultExchangeRate() public {
        address user = makeAddr("conversionUser");

        uint256 depositAmount = 100 * 10 ** 6;
        uint256 sharesToConvert = 25 * 10 ** 9;

        usdc.mint(user, depositAmount);

        vm.startPrank(user);
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user);
        vm.stopPrank();

        uint256 assets = vault.convertToAssets(sharesToConvert);

        assertEq(assets, 25 * 10 ** 6);
    }

    function test_PreviewDepositMatchesActualSharesReceived() public {
        address user = makeAddr("previewUser");

        uint256 depositAmount = 100 * 10 ** 6;

        usdc.mint(user, depositAmount);

        uint256 expectedShares = vault.previewDeposit(depositAmount);

        vm.startPrank(user);
        usdc.approve(address(vault), depositAmount);

        uint256 actualShares = vault.deposit(depositAmount, user);

        vm.stopPrank();

        assertEq(actualShares, expectedShares);
        assertEq(vault.balanceOf(user), expectedShares);
    }

    function test_PreviewRedeemMatchesActualAssetsReceived() public {
        address user = makeAddr("previewUser");

        uint256 depositAmount = 100 * 10 ** 6;

        usdc.mint(user, depositAmount);

        vm.startPrank(user);
        usdc.approve(address(vault), depositAmount);

        uint256 shares = vault.deposit(depositAmount, user);

        vm.stopPrank();

        uint256 expectedAssets = vault.previewRedeem(shares);

        vm.prank(user);
        uint256 actualAssets = vault.redeem(shares, user, user);

        assertEq(actualAssets, expectedAssets);
        assertEq(usdc.balanceOf(user), expectedAssets);
    }

    function test_ConversionsRoundDownAfterDirectDonation() public {
        address user = makeAddr("roundingUser");

        uint256 initialDeposit = 10 * 10 ** 6;

        usdc.mint(user, initialDeposit + 1);

        vm.startPrank(user);
        usdc.approve(address(vault), initialDeposit + 1);

        vault.deposit(initialDeposit, user);

        // Donation changes the exchange rate without minting shares.
        usdc.transfer(address(vault), 1);

        vm.stopPrank();

        // One smallest USDC unit converts to 999 shares after rounding down.
        assertEq(vault.convertToShares(1), 999);

        // One share is worth less than one smallest USDC unit.
        // The conversion rounds down to zero.
        assertEq(vault.convertToAssets(1), 0);

        assertEq(vault.previewDeposit(1), 999);
        assertEq(vault.previewRedeem(1), 0);
    }

    // ERC-4626 maximum limit tests

    function test_MaxDepositReturnsZeroWhilePaused() public {
        address user = makeAddr("limitUser");

        assertEq(vault.maxDeposit(user), type(uint256).max);

        vm.prank(owner);
        vault.pause();

        assertEq(vault.maxDeposit(user), 0);

        vm.prank(owner);
        vault.unpause();

        assertEq(vault.maxDeposit(user), type(uint256).max);
    }

    function test_MaxMintReturnsZeroWhilePaused() public {
        address user = makeAddr("limitUser");

        assertEq(vault.maxMint(user), type(uint256).max);

        vm.prank(owner);
        vault.pause();

        assertEq(vault.maxMint(user), 0);

        vm.prank(owner);
        vault.unpause();

        assertEq(vault.maxMint(user), type(uint256).max);
    }

    // UUPS upgrade tests

    function test_RevertWhenUnauthorizedUpgrade() public {
        AetherVault newImplementation = new AetherVault();

        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                attacker
            )
        );

        vm.prank(attacker);
        vault.upgradeToAndCall(address(newImplementation), "");
    }

    function test_AuthorizedUpgradePreservesVaultState() public {
        address user = makeAddr("user");
        uint256 depositAmount = 100 * 10 ** 6;

        usdc.mint(user, depositAmount);

        vm.startPrank(user);
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user);
        vm.stopPrank();

        AetherVaultV2 newImplementation = new AetherVaultV2();

        vm.prank(owner);
        vault.upgradeToAndCall(address(newImplementation), "");

        AetherVaultV2 upgradedVault = AetherVaultV2(address(vault));

        assertEq(upgradedVault.version(), 2);
        assertEq(upgradedVault.owner(), owner);
        assertEq(upgradedVault.asset(), address(usdc));
        assertEq(upgradedVault.balanceOf(user), depositAmount * 1000);
        assertEq(upgradedVault.totalAssets(), depositAmount);
        assertEq(upgradedVault.decimals(), 9);
    }

    // Emergency pause tests

    function test_OwnerCanPauseVault() public {
        vm.prank(owner);
        vault.pause();

        assertTrue(vault.paused());
    }

    function test_OwnerCanUnpauseVault() public {
        vm.prank(owner);
        vault.pause();

        vm.prank(owner);
        vault.unpause();

        assertFalse(vault.paused());
    }

    function test_RevertWhenNonOwnerPausesVault() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                attacker
            )
        );

        vm.prank(attacker);
        vault.pause();
    }

    function test_RevertWhenDepositingWhilePaused() public {
        address user = makeAddr("user");
        uint256 amount = 100 * 10 ** 6;

        usdc.mint(user, amount);

        vm.prank(owner);
        vault.pause();

        vm.startPrank(user);
        usdc.approve(address(vault), amount);

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vault.deposit(amount, user);

        vm.stopPrank();
    }

    function test_RevertWhenMintingWhilePaused() public {
        address user = makeAddr("user");

        vm.prank(owner);
        vault.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        vm.prank(user);
        vault.mint(100 * 10 ** 6, user);
    }

    // Inflation attack mitigation test

    function test_InflationAttackMitigation() public {
        address victim = makeAddr("victim");

        usdc.mint(attacker, 1);

        vm.startPrank(attacker);
        usdc.approve(address(vault), 1);
        vault.deposit(1, attacker);
        vm.stopPrank();

        uint256 donation = 1 * 10 ** 6;

        usdc.mint(attacker, donation);

        vm.prank(attacker);
        usdc.transfer(address(vault), donation);

        uint256 victimDeposit = 1 * 10 ** 6;

        usdc.mint(victim, victimDeposit);

        vm.startPrank(victim);
        usdc.approve(address(vault), victimDeposit);

        uint256 victimShares = vault.deposit(victimDeposit, victim);

        vm.stopPrank();

        assertGt(victimShares, 0);

        uint256 recoverableAssets = vault.previewRedeem(victimShares);

        assertGt(recoverableAssets, victimDeposit * 99 / 100);
    }
}

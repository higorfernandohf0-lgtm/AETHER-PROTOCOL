// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AetherOracleGuard} from "../../src/oracles/AetherOracleGuard.sol";
import {MockAggregatorV3} from "../mocks/MockAggregatorV3.sol";

contract AetherOracleGuardTest is Test {
    MockAggregatorV3 internal mockFeed;
    AetherOracleGuard internal guard;

    uint256 internal constant STALENESS_THRESHOLD = 1 hours;
    int256 internal constant MIN_PRICE = 1000e8; // $1,000
    int256 internal constant MAX_PRICE = 5000e8; // $5,000

    function setUp() public {
        // Mock do Chainlink com preço inicial de $2,000 e atualizado agora
        mockFeed = new MockAggregatorV3(2000e8, block.timestamp);

        guard = new AetherOracleGuard(
            address(mockFeed),
            STALENESS_THRESHOLD,
            MIN_PRICE,
            MAX_PRICE
        );
    }

    function test_GetValidatedPriceReturnsCorrectPrice() public view {
        int256 price = guard.getValidatedPrice();
        assertEq(price, 2000e8);
    }

    function test_RevertWhenPriceIsStale() public {
        // Avança o tempo além do threshold de staleness
        vm.warp(block.timestamp + STALENESS_THRESHOLD + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                AetherOracleGuard.StalePrice.selector,
                block.timestamp - STALENESS_THRESHOLD - 1
            )
        );
        guard.getValidatedPrice();
    }

    function test_RevertWhenPriceIsBelowMin() public {
        mockFeed.setAnswer(MIN_PRICE - 1, block.timestamp);

        vm.expectRevert(
            abi.encodeWithSelector(
                AetherOracleGuard.PriceOutOfBounds.selector,
                MIN_PRICE - 1
            )
        );
        guard.getValidatedPrice();
    }

    function test_RevertWhenPriceIsAboveMax() public {
        mockFeed.setAnswer(MAX_PRICE + 1, block.timestamp);

        vm.expectRevert(
            abi.encodeWithSelector(
                AetherOracleGuard.PriceOutOfBounds.selector,
                MAX_PRICE + 1
            )
        );
        guard.getValidatedPrice();
    }

    function test_RevertWhenPriceIsInvalid() public {
        mockFeed.setAnswer(0, block.timestamp);

        vm.expectRevert(AetherOracleGuard.InvalidPrice.selector);
        guard.getValidatedPrice();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract AetherVault is
    Initializable,
    ERC4626Upgradeable,
    Ownable2StepUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        IERC20 usdc,
        address initialOwner
    ) external initializer {
        require(address(usdc) != address(0), "Invalid USDC");
        require(initialOwner != address(0), "Invalid owner");

        __ERC20_init("Aether USDC Vault", "aUSDC");
        __ERC4626_init(usdc);
        __Ownable_init(initialOwner);
        __Ownable2Step_init();
        __Pausable_init();
    }

    // Emergency controls

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // ERC-4626 deposit protection

    function deposit(
        uint256 assets,
        address receiver
    ) public override whenNotPaused returns (uint256) {
        return super.deposit(assets, receiver);
    }

    function mint(
        uint256 shares,
        address receiver
    ) public override whenNotPaused returns (uint256) {
        return super.mint(shares, receiver);
    }

    // ERC-4626 maximum limits

    function maxDeposit(
        address receiver
    ) public view override returns (uint256) {
        if (paused()) {
            return 0;
        }

        return super.maxDeposit(receiver);
    }

    function maxMint(
        address receiver
    ) public view override returns (uint256) {
        if (paused()) {
            return 0;
        }

        return super.maxMint(receiver);
    }

    // Inflation attack mitigation

    function _decimalsOffset() internal pure override returns (uint8) {
        return 3;
    }

    // UUPS upgrade authorization

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}

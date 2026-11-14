// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IAaveStrategy {
    function supply(uint256 amount) external;
    function withdraw(uint256 amount) external returns (uint256);
    function totalAssets() external view returns (uint256);
}

interface IOracleGuard {
    function getValidatedPrice() external view returns (int256);
}

contract AetherVault is
    Initializable,
    ERC4626Upgradeable,
    Ownable2StepUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;

    IAaveStrategy public strategy;
    IOracleGuard public oracleGuard;
    uint256 public allocationCap;

    event StrategySet(address indexed strategy);
    event OracleGuardSet(address indexed oracleGuard);
    event Allocated(uint256 amount);
    event Deallocated(uint256 amount);
    event EmergencyWithdraw(uint256 amount);
    event AllocationCapSet(uint256 cap);

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

    function setStrategy(address _strategy) external onlyOwner {
        require(_strategy != address(0), "Invalid strategy");
        strategy = IAaveStrategy(_strategy);
        emit StrategySet(_strategy);
    }

    function setOracleGuard(address _oracleGuard) external onlyOwner {
        require(_oracleGuard != address(0), "Invalid oracle");
        oracleGuard = IOracleGuard(_oracleGuard);
        emit OracleGuardSet(_oracleGuard);
    }

    function setAllocationCap(uint256 _cap) external onlyOwner {
        allocationCap = _cap;
        emit AllocationCapSet(_cap);
    }

    function allocate(uint256 amount) external onlyOwner {
        require(address(strategy) != address(0), "Strategy not set");
        require(amount > 0, "Amount must be > 0");
        
        uint256 currentStrategyBalance = strategy.totalAssets();
        require(currentStrategyBalance + amount <= allocationCap, "Exceeds allocation cap");

        IERC20(asset()).safeTransfer(address(strategy), amount);
        strategy.supply(amount);
        emit Allocated(amount);
    }

    function deallocate(uint256 amount) external onlyOwner {
        require(address(strategy) != address(0), "Strategy not set");
        require(amount > 0, "Amount must be > 0");
        
        uint256 withdrawn = strategy.withdraw(amount);
        require(withdrawn == amount, "Withdraw failed");

        IERC20(asset()).safeTransferFrom(address(strategy), address(this), amount);
        emit Deallocated(amount);
    }

    function emergencyWithdraw() external onlyOwner {
        require(address(strategy) != address(0), "Strategy not set");
        
        uint256 strategyBalance = strategy.totalAssets();
        if (strategyBalance > 0) {
            strategy.withdraw(strategyBalance);
            IERC20(asset()).safeTransferFrom(address(strategy), address(this), strategyBalance);
            emit EmergencyWithdraw(strategyBalance);
        }
    }

    function totalAssets() public view override returns (uint256) {
        uint256 vaultBalance = IERC20(asset()).balanceOf(address(this));
        uint256 strategyBalance = 0;
        
        if (address(strategy) != address(0)) {
            strategyBalance = strategy.totalAssets();
        }
        
        return vaultBalance + strategyBalance;
    }

    function deposit(uint256 assets, address receiver) public override whenNotPaused returns (uint256) {
        if (address(oracleGuard) != address(0)) {
            oracleGuard.getValidatedPrice();
        }
        return super.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver) public override whenNotPaused returns (uint256) {
        if (address(oracleGuard) != address(0)) {
            oracleGuard.getValidatedPrice();
        }
        return super.mint(shares, receiver);
    }

    function maxDeposit(address receiver) public view override returns (uint256) {
        if (paused()) return 0;
        return super.maxDeposit(receiver);
    }

    function maxMint(address receiver) public view override returns (uint256) {
        if (paused()) return 0;
        return super.maxMint(receiver);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _decimalsOffset() internal pure override returns (uint8) {
        return 3;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
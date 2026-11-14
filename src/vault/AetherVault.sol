// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Interface mínima da Estratégia
interface IAaveStrategy {
    function supply(uint256 amount) external;
    function withdraw(uint256 amount) external returns (uint256);
    function totalAssets() external view returns (uint256);
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

    // Eventos
    event StrategySet(address indexed strategy);
    event Allocated(uint256 amount);
    event Deallocated(uint256 amount);

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

    // --- Funções de Estratégia ---

    function setStrategy(address _strategy) external onlyOwner {
        require(_strategy != address(0), "Invalid strategy");
        strategy = IAaveStrategy(_strategy);
        emit StrategySet(_strategy);
    }

    function allocate(uint256 amount) external onlyOwner {
        require(address(strategy) != address(0), "Strategy not set");
        require(amount > 0, "Amount must be > 0");
        
        IERC20(asset()).safeTransfer(address(strategy), amount);
        strategy.supply(amount);
        emit Allocated(amount);
    }

    function deallocate(uint256 amount) external onlyOwner {
        require(address(strategy) != address(0), "Strategy not set");
        require(amount > 0, "Amount must be > 0");
        
        // 1. Manda a estratégia sacar do Aave (o dinheiro vai para a Estratégia)
        uint256 withdrawn = strategy.withdraw(amount);
        require(withdrawn == amount, "Withdraw failed");

        // 2. Puxa o dinheiro da Estratégia de volta para o Vault
        IERC20(asset()).safeTransferFrom(address(strategy), address(this), amount);

        emit Deallocated(amount);
    }

    function totalAssets() public view override returns (uint256) {
        uint256 vaultBalance = IERC20(asset()).balanceOf(address(this));
        uint256 strategyBalance = 0;
        
        if (address(strategy) != address(0)) {
            strategyBalance = strategy.totalAssets();
        }
        
        return vaultBalance + strategyBalance;
    }

    // --- Controles de Emergência ---

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function deposit(uint256 assets, address receiver) public override whenNotPaused returns (uint256) {
        return super.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver) public override whenNotPaused returns (uint256) {
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

    function _decimalsOffset() internal pure override returns (uint8) {
        return 3;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

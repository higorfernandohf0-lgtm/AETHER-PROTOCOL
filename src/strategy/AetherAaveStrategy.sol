// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

interface IAToken {
    function balanceOf(address user) external view returns (uint256);
}

contract AetherAaveStrategy is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;
    IPool public immutable aavePool;
    IAToken public immutable aToken;

    event Supplied(uint256 amount);
    event Withdrawn(uint256 amount);

    constructor(
        address _asset,
        address _aavePool,
        address _aToken,
        address initialOwner
    ) Ownable(initialOwner) {
        require(_asset != address(0), "Invalid asset");
        require(_aavePool != address(0), "Invalid pool");
        require(_aToken != address(0), "Invalid aToken");

        asset = IERC20(_asset);
        aavePool = IPool(_aavePool);
        aToken = IAToken(_aToken);

        // Aprova o Aave Pool para gastar o USDC
        asset.forceApprove(_aavePool, type(uint256).max);
        
        // Aprova o owner (Vault) a puxar os fundos de volta após o withdraw
        asset.forceApprove(initialOwner, type(uint256).max);
    }

    /// @notice Deposita ativos no Aave
    function supply(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be > 0");
        aavePool.supply(address(asset), amount, address(this), 0);
        emit Supplied(amount);
    }

    /// @notice Retira ativos do Aave
    function withdraw(uint256 amount) external onlyOwner returns (uint256) {
        require(amount > 0, "Amount must be > 0");
        uint256 withdrawn = aavePool.withdraw(address(asset), amount, address(this));
        emit Withdrawn(withdrawn);
        return withdrawn;
    }

    /// @notice Retorna o saldo total em USDC (no contrato + no Aave)
    function totalAssets() external view returns (uint256) {
        return asset.balanceOf(address(this)) + aToken.balanceOf(address(this));
    }
}

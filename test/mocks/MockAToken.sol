// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockAToken {
    address public immutable underlyingAsset;
    address public immutable pool;

    constructor(address _underlyingAsset, address _pool) {
        underlyingAsset = _underlyingAsset;
        pool = _pool;
    }

    function balanceOf(address user) external view returns (uint256) {
        // O saldo do "aToken" é o saldo do Pool (já que ele guarda os tokens)
        return IERC20(underlyingAsset).balanceOf(pool);
    }
}
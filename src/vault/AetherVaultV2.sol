
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AetherVault} from "./AetherVault.sol";

contract AetherVaultV2 is AetherVault {
    function version() external pure returns (uint256) {
        return 2;
    }
}

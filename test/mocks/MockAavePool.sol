// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IFlashLoanSimpleReceiver} from "../../src/flashloan/AetherFlashLoanExecutor.sol";

contract MockAavePool {
    function supply(address asset, uint256 amount, address, uint16) external {
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        IERC20(asset).transfer(to, amount);
        return amount;
    }

    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata,
        address,
        bytes calldata params,
        uint16
    ) external {
        IERC20(assets[0]).transfer(receiverAddress, amounts[0]);

        bool success = IFlashLoanSimpleReceiver(receiverAddress).executeOperation(
            assets[0],
            amounts[0],
            0,
            receiverAddress, // <-- initiator é o próprio executor
            params
        );
        require(success, "Flash loan failed");

        IERC20(assets[0]).transferFrom(receiverAddress, address(this), amounts[0]);
    }
}
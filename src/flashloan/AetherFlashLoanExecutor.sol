// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IPool {
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata interestRateModes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface IFlashLoanSimpleReceiver {
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}

contract AetherFlashLoanExecutor is IFlashLoanSimpleReceiver, Ownable {
    using SafeERC20 for IERC20;

    IPool public immutable aavePool;

    event FlashLoanExecuted(address indexed asset, uint256 amount, uint256 premium);

    constructor(address _aavePool, address initialOwner) Ownable(initialOwner) {
        require(_aavePool != address(0), "Invalid Aave Pool");
        aavePool = IPool(_aavePool);
    }

    function requestFlashLoan(
        address asset,
        uint256 amount,
        bytes calldata params
    ) external onlyOwner {
        address[] memory assets = new address[](1);
        assets[0] = asset;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        uint256[] memory interestRateModes = new uint256[](1);
        interestRateModes[0] = 0; // 0 = Flash Loan sem juros (devolve apenas a taxa do Aave)

        aavePool.flashLoan(
            address(this),
            assets,
            amounts,
            interestRateModes,
            address(this),
            params,
            0
        );
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        require(msg.sender == address(aavePool), "Caller must be Aave Pool");
        require(initiator == address(this), "Initiator must be this contract");

        // =========================================================
        // AQUI É ONDE A MÁGICA ACONTECE.
        // Exemplo: arbitragem, liquidação de dívidas, ou trocar em outra DEX.
        // Para o portfólio, vamos apenas validar se o contrato tem saldo
        // suficiente para pagar o empréstimo + prêmio. Em produção, a lógica
        // de negócio deve gerar lucro suficiente para cobrir o prêmio.
        // =========================================================
        
        // O valor total a ser devolvido ao Aave = empréstimo + prêmio (taxa)
        uint256 amountToRepay = amount + premium;

        // Verifica se o contrato tem saldo para pagar (isso simula o lucro)
        require(IERC20(asset).balanceOf(address(this)) >= amountToRepay, "Insufficient funds to repay");

        // Aprova o Aave para pegar o valor de volta
        IERC20(asset).forceApprove(address(aavePool), amountToRepay);

        emit FlashLoanExecuted(asset, amount, premium);

        return true;
    }

    function withdraw(address asset, uint256 amount) external onlyOwner {
        IERC20(asset).safeTransfer(owner(), amount);
    }
}
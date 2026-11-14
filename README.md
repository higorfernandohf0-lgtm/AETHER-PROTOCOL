# AETHER PROTOCOL

**Upgradeable DeFi Vault & Risk Management Infrastructure**

[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-blue)]()
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-orange)]()
[![Tests](https://img.shields.io/badge/Tests-56%20passing-brightgreen)]()
[![Sepolia](https://img.shields.io/badge/Deployed-Sepolia-purple)]()

---

## 📌 Status

| Module | Status | Description |
|--------|--------|-------------|
| ERC-4626 Vault | ✅ Implemented & Tested | Yield-bearing vault with Aave integration |
| AetherToken (ERC20Votes) | ✅ Deployed | Governance token |
| TimelockController | ✅ Deployed | 2-day delay executor |
| AetherGovernor | ✅ Deployed | Proposal and voting system |
| Aave V3 Strategy | ✅ Integrated | Allocates capital to Aave V3 |
| Oracle Guard (Chainlink) | ✅ Integrated | Blocks deposits on stale/manipulated prices |
| Flash Loan Executor | 🟡 Experimental | Proof of Concept for future arbitrage/liquidations |

---

## 🏗️ Architecture & Flow

**Deposit Flow:**
1. User deposits USDC into the Vault (ERC-4626).
2. Vault consults the Oracle Guard to validate the USDC price (Chainlink).
3. Vault mints shares to the user.
4. Owner/Governance calls `allocate()` to send idle capital to the Aave Strategy.
5. The Strategy supplies the USDC to Aave V3 and receives aTokens.

**Governance Flow:**
1. Token holders propose changes via the Governor.
2. Voting occurs over 1 week.
3. Approved proposals are queued in the Timelock (2-day delay).
4. The Timelock executes the action on the Vault.

---

## 🧪 Test Results

- **56 automated tests passing** (unit, fuzz, invariant, and integration tests).
- **128,000 invariant handler calls** without reverts.
- Protection against ERC-4626 share inflation via `_decimalsOffset()`.

---

## 🔐 Security Features

- **UUPS Upgradeability** controlled by `Ownable2Step`.
- **Share Inflation Protection** via `_decimalsOffset()`.
- **Emergency Pause** (deposits/mint halted, withdrawals remain active).
- **Allocation Cap**: Limits the maximum capital sent to the Aave strategy.
- **Emergency Withdraw**: Allows the owner to pull all funds from Aave in a crisis.
- **Oracle Guard**: Blocks deposits if the price is stale or out of bounds.
- **Automated Testing**: CI/CD via GitHub Actions.

---

## ⚠️ Known Limitations & Risks

1. **Oracle Dependency**: The Vault relies on Chainlink for USDC price validation. If the oracle is compromised or unavailable, deposits may be blocked. (Mitigation: the guard only blocks deposits, not withdrawals).
2. **Aave Smart Contract Risk**: Capital allocated to Aave is subject to the risks of the Aave protocol (e.g., smart contract bugs, liquidity crunches).
3. **Flash Loan Executor**: This module is currently a **Proof of Concept**. It demonstrates how to receive and repay a flash loan, but does not yet implement a profitable arbitrage or liquidation strategy. It is not intended for production use in its current state.
4. **Centralization**: The Vault owner is currently an EOA (Externally Owned Account). The next step is to transfer ownership to the TimelockController for full decentralization.

---

## 🛠️ Tech Stack

Solidity 0.8.24 · Foundry · OpenZeppelin · ERC-4626 · UUPS · Aave V3 · Chainlink

---

## 🚀 Quick Start

```bash
git clone https://github.com/higorfernandohf0-lgtm/AETHER-PROTOCOL.git
cd AETHER-PROTOCOL
forge install
forge build
forge test
📄 License
MIT

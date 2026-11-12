# AETHER PROTOCOL — Tokenomics v1

**Status:** Draft — design phase  
**Version:** 1.0  
**Token:** AETHER  
**Governance model:** ERC20Votes + Governor + Timelock  
**Treasury custody:** Safe multisig

---

## 1. Design Principles

AETHER Protocol adopts a treasury-first token distribution model.

The initial supply is intended to be allocated to protocol treasury custody. Governance voting power will be distributed through independent delegates, while treasury assets remain protected by multisignature controls.

The design follows five principles:

1. Fixed initial supply with no discretionary minting.
2. Separation between asset custody and governance voting.
3. Historical voting power through ERC20Votes checkpoints.
4. Governance execution protected by a Timelock.
5. Transparent and testable allocation rules.

This document describes the proposed design. It does not represent a deployed token, operational treasury, or active governance system.

## 2. Token Specification

| Parameter | Proposed value |
|---|---|
| Token name | AETHER |
| Token symbol | AETHER |
| Standard | ERC-20 |
| Voting extension | ERC20Votes |
| Signature extension | ERC20Permit |
| Decimals | 18 |
| Initial supply | 100,000,000 AETHER |
| Additional minting | Disabled |
| Upgradeability | Not planned |

The initial supply is intended to be minted once during deployment and assigned to the treasury.

The token contract should not expose a discretionary mint function.

## 3. Treasury Custody

The main treasury is intended to use a Safe multisig wallet.

| Parameter | Proposed configuration |
|---|---|
| Signers | 5 independent signers |
| Approval threshold | 3 of 5 |
| Custody mechanism | Safe multisig |
| Treasury control | Multisignature approvals |

The 3-of-5 threshold is a proposed custody configuration. It is separate from the voting rules of the Governor contract.

A governance delegate does not automatically receive permission to transfer treasury assets.

## 4. Initial Voting Distribution

The initial governance simulation uses five independent representatives.

| Allocation | Amount |
|---|---:|
| Delegate 1 | 10,000,000 AETHER |
| Delegate 2 | 10,000,000 AETHER |
| Delegate 3 | 10,000,000 AETHER |
| Delegate 4 | 10,000,000 AETHER |
| Delegate 5 | 10,000,000 AETHER |
| Treasury reserve | 50,000,000 AETHER |
| **Total** | **100,000,000 AETHER** |

Each delegate allocation represents 10% of the initial supply.

The five delegate allocations represent 50% of the supply. The remaining 50% is reserved in treasury custody and is initially not delegated.

**Important:** This is a proposed simulation structure, not a final distribution or a completed transfer.

### 4.1 Separate custody and voting

ERC20Votes assigns voting power through delegation.

If all tokens remain in one treasury wallet and that wallet delegates its entire balance to one representative, that representative can receive the voting power associated with the entire delegated balance.

To avoid this concentration, the proposed structure uses separate wallets for the five delegate allocations.

Each allocation should remain under appropriate custody controls. Delegation grants voting power, not independent authority over treasury assets.

### 4.2 Delegate independence

The five representatives should:

- Operate independently.
- Avoid shared control of their delegate wallets.
- Disclose relevant conflicts of interest.
- Participate in governance discussions.
- Vote according to their own assessment of proposals.

The final delegate selection and replacement policy remain to be defined.

## 5. Voting Architecture

The proposed governance stack consists of:

- **ERC20Votes:** historical voting power and delegation.
- **ERC20Permit:** signature-based token approvals.
- **Governor:** proposal creation, voting, and execution coordination.
- **GovernorCountingSimple:** For, Against, and Abstain voting.
- **GovernorVotesQuorumFraction:** quorum based on total token supply.
- **GovernorTimelockControl:** delayed execution through Timelock.
- **TimelockController:** execution delay and access control.

### 5.1 Delegation

Token holders must delegate their voting power to themselves or another address.

Voting power is based on historical checkpoints, not simply the current token balance.

### 5.2 Quorum

**Initial simulation target: 15% of total supply.**

With an initial supply of 100 million AETHER:

- 15% quorum = 15 million votes.
- Two delegates with 10 million votes each could reach quorum if both participate.
- One delegate alone would not reach quorum.

This is a simulation parameter, not a final production decision.

Quorum participation and proposal approval are separate conditions. Under GovernorCountingSimple, quorum counts For and Abstain votes, while approval requires For votes to exceed Against votes.

## 6. Security Boundaries

The governance architecture must preserve the separation between:

**Treasury custody**
- Safe multisig controls treasury transactions.
- The proposed main threshold is 3-of-5.
- Delegation alone does not authorize treasury transfers.

**Protocol administration**
- Governor coordinates approved proposals.
- Timelock delays execution.
- Protocol ownership should only be transferred to Timelock after the governance execution path has been tested.

**Token voting**
- ERC20Votes tracks delegated voting power.
- Historical checkpoints support snapshot-based voting.
- Fixed supply avoids discretionary inflation through additional minting.

## 7. Risks and Open Questions

The following topics must be evaluated before production deployment:

1. **Delegate concentration:** Five representatives may still create excessive voting concentration.
2. **Low participation:** A low quorum may allow a small number of participants to influence decisions.
3. **Inactive delegates:** A replacement and reallocation policy is required.
4. **Treasury reserve:** The rules for future delegation or distribution of the reserve must be defined.
5. **Conflicts of interest:** Delegate independence and disclosure requirements must be documented.
6. **Timelock delay:** The appropriate execution delay must be selected and tested.
7. **Proposal threshold:** The minimum voting power required to submit proposals remains undecided.
8. **Voting schedule:** Voting delay and voting period remain undecided.
9. **Emergency procedures:** The relationship between emergency controls and governance execution must be tested.

## 8. Implementation Roadmap

| Phase | Deliverable | Status |
|---|---|---|
| 1 | Tokenomics documentation | In progress |
| 2 | AETHER ERC-20 token | Not started |
| 3 | ERC20Votes and ERC20Permit tests | Not started |
| 4 | Governor implementation | Not started |
| 5 | TimelockController integration | Not started |
| 6 | Governance unit tests | Not started |
| 7 | Governance fuzz and invariant tests | Not started |
| 8 | Governance security review | Not started |
| 9 | Testnet deployment | Not started |
| 10 | Treasury and ownership configuration | Not started |

## 9. Important Disclaimer

AETHER tokenomics v1 is a design document.

The proposed allocations, delegate structure, quorum, multisig threshold, and governance architecture must be reviewed and tested before deployment.

Passing automated tests does not constitute a security audit. No production deployment or security guarantee is implied by this document.

---

**AETHER PROTOCOL — Governance and Tokenomics**  
*Design first. Test thoroughly. Deploy only after review.*
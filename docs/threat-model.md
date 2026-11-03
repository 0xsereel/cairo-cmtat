# Threat model

This document is for auditors. It lists what the token protects, who can do what, which external contracts are trusted, and where the residual risks are. Behaviour that matches CMTAT v3.3.0 (commit `3d9b0e9`) is marked as such, so you can tell inherited design choices from choices made in the port.

The [README](../README.md) covers the ABI, the roles, the check order and SRC5. [`parity.md`](parity.md) maps each CMTAT test to the Cairo tests that cover it.

---

## Scope

**In scope:**
- **Presets:** `src/presets/` (Light, Allowlist, Standard, Debt, Snapshot).
- **Components** in `src/components/`, and the check chains in `src/components/hooks.cairo`.
- **Role ids, errors and SNIP-5 interface ids:** `src/roles.cairo`, `src/errors.cairo` and `src/interfaces/`.

**Out of scope:**
- **Not ported:** DebtEngine, Permit, HolderList, the ERC-7551 module, cross-chain, and ERC-2771 meta-transactions.
- **Engine implementations:** RuleEngine and SnapshotEngine live outside this repository. `src/mocks/` holds test doubles only.
- **Dependencies:** OpenZeppelin Cairo v4.0.1 (ERC20, AccessControl, SRC5, Upgradeable, ReentrancyGuard) is a trusted dependency.

**Where the port's own logic is:**
- **Wrappers:** the ERC-20 wrappers in `erc20_base.cairo`, which run the checks before OpenZeppelin's `_transfer`.
- **Check chains:** `hooks.cairo`.
- **Freeze accounting:** partial freeze and forced transfer in `erc20_enforcement.cairo`.
- **Snapshot balances:** the derivation of pre-update balances in `snapshot.cairo`.
- **Versions:** the migration version guard in `upgrade.cairo`.

---

## Assets

| Asset | Where |
|---|---|
| Balances and total supply | OpenZeppelin `ERC20` storage |
| Allowances | OpenZeppelin `ERC20` storage |
| Frozen addresses and frozen amounts | `enforcement`, `erc20_enforcement` |
| Pause and deactivation flags | `pause` |
| Role assignments | OpenZeppelin `AccessControl` |
| Engine addresses (RuleEngine, SnapshotEngine) | `rule_engine`, `snapshot` |
| Allowlist and its enabled flag | `allowlist` |
| Off-chain references: documents, terms, information, token id, debt data | `documents`, `extra_information`, `debt` |
| The class hash and storage version | Starknet `replace_class`, `upgrade` |

---

## Actors and trust

| Actor | Trust | What it can do |
|---|---|---|
| `DEFAULT_ADMIN_ROLE` | **Fully trusted** | Holds every role implicitly (`has_role` is true for any role, as in CMTAT). Grants and revokes roles, upgrades the class, runs `migrate`, forced transfers and burns, deactivates, sets the RuleEngine, and renames the token. |
| Operational roles (`MINTER`, `BURNER*`, `PAUSER`, `ENFORCER`, `ERC20ENFORCER`, `ALLOWLIST`, `SNAPSHOOTER`, `DOCUMENT`, `EXTRA_INFORMATION`, `DEBT`) | Trusted within their scope | See the README role table. Each role's admin role is `DEFAULT_ADMIN_ROLE`. |
| RuleEngine | Trusted by the admin who sets it | Can block any transfer, mint or burn, and changes what the read functions return. It cannot move tokens through the token contract. |
| SnapshotEngine | Trusted by the `SNAPSHOOTER` who sets it | Is called after every balance change. A reverting engine blocks every balance change. |
| Holders and spenders | Untrusted | Use the ERC-20 calls and their own allowances, subject to the checks. |
| Anyone | Untrusted | Calls the read functions. |

The admin key is the single point of failure. Deploy with a multisig or governance account as admin, and give operational roles to separate accounts.

---

## Security properties

Each property names the tests that pin it.

1. **Every non-forced balance change runs the full check chain.** This covers `transfer`, `transfer_from`, `batch_transfer`, mint, burn, `burn_from`, `burn_self` and `burn_and_mint`. The order is:
   1. active balance;
   2. the allowlist (Allowlist preset);
   3. pause, for transfers only;
   4. deactivation, for mint and burn only;
   5. freeze checks;
   6. the RuleEngine.

   Each failure produces exactly one error. *Tests:* `test_validation_matrix` (every preset, every pause, deactivation and freeze state, 12 operations).
2. **A holder with frozen tokens can move only the unfrozen balance.** Forced transfers are the exception: they consume frozen tokens only for the shortfall. *Tests:* `erc20_enforcement::forced_transfer_*`, `erc1404::reads_at_nonzero_active_balance_boundary`, `test_fuzz`.
3. **Pause does not block mint or burn. Deactivation blocks both and makes the pause permanent.** A transfer on a deactivated token reverts with the pause error (CMTAT). *Tests:* `pause::*`, matrix.
4. **An allowance can always be revoked.** `approve(spender, 0)` succeeds when the token is paused or deactivated, when the owner or spender is frozen, and when the spender has been removed from the allowlist (NM-3). *Tests:* `erc20_base::approve_zero_*`, `allowlist::approve_zero_after_spender_is_delisted`.
5. **A RuleEngine cannot reenter the token during `transferred`.** The call runs inside OpenZeppelin's `ReentrancyGuard`, before balances move. *Tests:* `rule_engine::reentrant_engine_*`.
6. **Only the admin can upgrade or migrate. Each migration version runs once, in increasing order.** *Tests:* `test_upgrade`, `presets::upgrade_requires_default_admin`.
7. **No preset deploys without an admin.** *Tests:* `presets::constructor_rejects_zero_admin`.
8. **Storage survives an upgrade in every module,** including the SnapshotEngine, terms and information. *Tests:* `upgrade::upgrade_and_migrate_keep_storage`, `snapshot_upgrade_keeps_snapshot_engine`.

---

## Threats and mitigations

### T1. Admin key compromise or loss
- **Compromise:**
  - **Impact:** an attacker can do everything. They can upgrade to an arbitrary class, mint without limit (minting is uncapped, as in CMTAT), and forced-transfer any balance.
  - **Mitigation:** none in the contract, by design (CMTAT). Use a multisig or governance account.
- **Loss:**
  - **Impact:** the token can never be upgraded or administered again. `renounce_role(DEFAULT_ADMIN_ROLE)` and revoking the last admin are both allowed.
  - **Mitigation:** none in the contract. Hand over adminship by granting the role to the new admin before renouncing (`access::admin_can_hand_over_adminship`).

### T2. Malicious or faulty upgrade
- **Arbitrary code:** `upgrade` replaces the class with no timelock, so the new class can do anything.
- **Deactivation can be undone:** `upgrade` does not check deactivation, so an upgrade can clear the deactivated flag. This matches a CMTAT proxy, whose upgrade authorisation also ignores deactivation.
- **Storage collisions:**
  - All storage names carry a module prefix (for example `ERC20EnforcementModule_frozen_tokens`). A new class must keep the existing names and types.
  - The tests check storage after an upgrade to the V2 mocks, but nothing checks layout automatically between releases.
  - **Review point:** compare storage between the deployed class and any upgrade class.
- **Unmigrated window:**
  - If `upgrade` and `migrate` go in separate transactions, users can transact against the new class before its storage is migrated.
  - **Mitigation:** send both in one account multicall (README, Upgrades). Only the admin can call `migrate`, so nobody else can front-run it.

### T3. Malicious or faulty RuleEngine (Standard, Debt, Snapshot)
- **Denial of service:** a reverting engine blocks every transfer, mint and burn.
  - **Recovery:** the admin can still replace it, because `set_rule_engine` never calls the engine. Forced transfers don't call it either.
- **Reads:** `can_transfer(_from)` and `detect_transfer_restriction(_from)` call the engine. A reverting engine makes them revert, and a lying engine makes them lie.
- **Reentrancy:**
  - `transferred` runs under the guard, so a reentrant call into any guarded path reverts.
  - Read calls are views and are not guarded.
  - **Review point:** check that every write path that calls the engine goes through `RuleEngineComponent::transferred`.
- **Recorded state:** the engine is called before the balance update. An engine that tracks its own state sees the operation before it settles, and the operation can still revert afterwards (for example on insufficient balance). This matches CMTAT.

### T4. Malicious or faulty SnapshotEngine (Snapshot preset)
- **Who sets it:** the engine is set by `SNAPSHOOTER_ROLE`, not the admin.
- **Denial of service:**
  - A reverting engine blocks every balance change, including forced transfers and burns.
  - **Recovery:** a `SNAPSHOOTER` (or the admin, which holds every role) can replace it, because `set_snapshot_engine` never calls the engine.
- **Not under the reentrancy guard:**
  - `operate_on_transfer` runs from OpenZeppelin's `after_update` hook, after balances are written.
  - It runs before `Spend` is emitted in `transfer_from`, and before `ForcedTransfer` is emitted in forced transfers.
  - A reentrant engine sees settled balances. It could only move tokens it holds or is approved for.
  - **Review point:** confirm that no invariant depends on code that runs after `_transfer` in the same call.
- **Pre-update values:**
  - CMTAT passes balances and total supply from before the update. The hook only sees the values after it, so the port derives the earlier values from the amount (`snapshot.cairo`).
  - Self-transfers pass the unchanged balances. Mint and burn pass 0 for the zero address.
  - **Review point:** this arithmetic. *Tests:* `snapshot::*`.

### T5. Forced transfers bypass compliance
- **What is skipped:** `forced_transfer(_with_data)`, `forced_burn` and `forced_transfer(from, 0)` skip pause, deactivation, freeze, allowlist and the RuleEngine.
- **Who can call them:** they require the admin and work on a deactivated token. This matches CMTAT, whose `forcedTransfer` has only the role modifier.
- **What they consume:**
  - Frozen tokens, but only the shortfall.
  - Any `from → to` allowance, capped at the allowance. They emit `Spend` with the amount taken and no `Approval`, and an infinite allowance is untouched (CMTAT).
- **Self transfers:** `forced_transfer(from, from)` reverts, so it cannot release frozen tokens (CMTAT).
- **Light's `forced_burn`:** requires the target to be frozen.

### T6. Read path and revert path disagree
- **Codes differ:** `detect_transfer_restriction` checks in a different order from the revert path (README, Transfer validation). The two agree on whether a transfer is allowed, but the reported code can differ.
- **`can_transfer` is not a balance check:**
  - When nothing is frozen, `can_transfer(from, to, value)` returns true even above the balance, because the active-balance check only runs while tokens are frozen. This matches CMTAT (`testUnfreezeTotalAndTransferMoreActiveBalance`).
  - The transfer itself reverts on balance (`erc20_base::full_unfreeze_restores_whole_balance`).
  - Integrators should not use `can_transfer` as a balance check.

### T7. Freeze accounting
- **Freezing above the balance:**
  - `freeze_partial_tokens` requires the new frozen total to be no more than the balance.
  - `set_frozen_tokens` (ERC-7943) may go above the balance; the active balance is then 0.
  - A mint to such an account makes only the part above the frozen amount transferable (`erc1404::mint_to_account_frozen_above_balance`).
- **Burns:** a burn checks the active balance. Only forced paths consume frozen tokens.
- **Arithmetic:** active balance = balance − frozen, saturating at 0. *Tests:* `test_fuzz`.

### T8. Allowlist (Allowlist preset)
- **Starts closed:** the allowlist is enabled and empty at deployment, so nothing can be minted or moved until addresses are listed.
- **Check order:** the allowlist runs before pause and freeze, so an address that is both unlisted and frozen reverts with the allowlist error.
- **Disabling:** `ALLOWLIST_ROLE` can turn the allowlist off, which opens transfers to everyone not otherwise blocked.

### T9. Input handling and gas
- **Batch calls:**
  - Batch calls have no length cap. Each is atomic and bounded only by the caller's gas.
  - The checks run in this order: role, then empty input, then length mismatch.
- **Event data:** `data` spans and `ByteArray` fields (documents, terms, information) are emitted or stored as given, with no size limit beyond gas.
- **Zero address:** address freezes and partial freezes reject the zero address. Allowlist updates accept it, but it has no effect: the allowlist check skips the zero side of a mint or burn.

---

## Differences from CMTAT that affect security

| Area | Port | Effect |
|---|---|---|
| Upgrades | Starknet `replace_class` under `DEFAULT_ADMIN_ROLE`, not a proxy with `PROXY_UPGRADE_ROLE` | One role controls upgrades. There is no separate proxy admin. |
| Migrations | `reinitializer(version)` requires the admin | Solidity's `reinitializer` is not role-gated. Here a stranger cannot run a migration. |
| Role ids | `selector!` (`sn_keccak`) | Off-chain tooling must not reuse Solidity role hashes. |
| Errors | 31-character felt short strings, some abbreviated | Integrators match on the names in `src/errors.cairo`, not on Solidity selectors. |
| Document names | `felt252` (31 bytes) | One byte shorter than `bytes32`. Longer names cannot be stored. |
| Meta-transactions | Not ported | Starknet accounts and paymasters cover this use. There is no trusted forwarder. |
| SNIP-5 ids | Computed from Cairo signatures | ERC-1404 and ERC-1643 ids depend on the `ByteArray` encoding (README, Interface ids). |

---

## Assurance so far

- **Tests:** 345 `snforge` tests, including:
  - the validation matrix on every preset;
  - exact event sequences per preset;
  - fuzz tests of the freeze arithmetic;
  - upgrade and migrate tests.
- **CMTAT parity:** 308 of the 343 in-scope CMTAT cases are covered, 18 are partial (minor details noted per row) and 17 don't apply ([`parity.md`](parity.md)).
- **Mutation checks:** run by hand while the tests were written. Each mutation was caught, then reverted:
  - burn-and-mint leg order;
  - event flattening;
  - spender forwarding;
  - the version guard;
  - forced-transfer unfreeze;
  - the `Spend` amount;
  - the input-check order.
- **CI:** format check, warning-free build, tests with coverage, and class size limits.
- **Not yet done:**
  - deployment to a public network;
  - an automated storage-layout diff between releases;
  - an external review of engine implementations.

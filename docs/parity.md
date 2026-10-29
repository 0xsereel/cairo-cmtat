# Test parity with CMTAT v3.3.0

This document maps each test case in CMTAT v3.3.0's test suite (commit `3d9b0e9`, Hardhat, `test/common/*Common.js`) to the Cairo tests that cover the same behaviour. CMTAT's `standard/`, `proxy/` and `deployment/` test files run these shared families against each deployment variant. The Cairo port does the same with its component suites, the validation matrix, which runs against every preset, and the shared preset suite.

Every row was checked against the body of the Cairo test, not just its name.

| Status | Meaning |
|---|---|
| **covered** | A Cairo test asserts the same behaviour. |
| **partial** | The behaviour is tested, but one detail CMTAT asserts is not. The note says which. |
| **gap** | In scope, but no test yet. |
| **n/a** | Doesn't apply to the port. The note gives the reason. |

Test references are `file::function`, relative to `tests/` and without the `test_` prefix. For example, `erc20_enforcement::forced_transfer_to_zero_burns` refers to `tests/test_erc20_enforcement.cairo`. `matrix` is `test_validation_matrix.cairo`, and `preset_events::run_core` and `run_common` are the shared sequences in `test_preset_events.cairo`.

## Differences that apply everywhere

These differences are not counted as partial anywhere in the tables:
- **Role errors.** OpenZeppelin Cairo's `MISSING_ROLE` (`'Caller is missing role'`) carries no arguments, so CMTAT's `.withArgs(account, role)` on `AccessControlUnauthorizedAccount` has no counterpart.
- **Overloaded events.** CMTAT's overloaded events with and without a reason (`TokensFrozen`, `TokensUnfrozen`, `ForcedTransfer`) are one Cairo event that always carries `data`, and `operator` for `ForcedTransfer`. Asserting that one event covers both Solidity variants.
- **Admin paths.** Component tests usually call as the holder of the specific role. The admin's access to every role is covered once per preset by `presets::admin_holds_every_role`, and `preset_events` / `fuzz` call the main operations as the admin on each preset.
- **RuleEngine mock.** CMTAT's `RuleEngineMock` decides by amount (at most 20, or 25 for a mint). The Cairo `RuleEngineRecorder` records calls and uses flags (`set_reject`, `set_can_transfer`, `set_code`, `set_reenter`). Cases phrased as "amount too high" therefore map to tests where the engine returns a configured code.
- **Failed calls.** Starknet has no `try`/`catch`. A failed inner call reverts the whole transaction, so cases where the RuleEngine catches a failed reentrant call can't be expressed.

## Summary

| Family (CMTAT `test/common/…`) | Cases | Covered | Partial | Gap | n/a |
|---|---:|---:|---:|---:|---:|
| `ERC20MintModuleCommon` | 34 | 31 | 1 | 2 | 0 |
| `ERC20BurnModuleCommon` | 30 | 26 | 1 | 3 | 0 |
| `ERC20BaseModuleCommon` | 25 | 18 | 5 | 2 | 0 |
| `ERC20EnforcementModuleCommon` | 56 | 52 | 4 | 0 | 0 |
| `ERC20EnforcementERC7551ModuleCommon` | 4 | 4 | 0 | 0 | 0 |
| `EnforcementModuleCommon` | 21 | 16 | 5 | 0 | 0 |
| `ValidationModule/ValidationModuleCommon` | 27 | 24 | 3 | 0 | 0 |
| `ValidationModule/ValidationModuleCommonCore` | 4 | 4 | 0 | 0 | 0 |
| `ValidationModule/ValidationModuleSetRuleEngineCommon` | 6 | 4 | 1 | 0 | 1 |
| `ValidationModule/RuleEngineReentrancyCommon` | 7 | 5 | 1 | 0 | 1 |
| `ValidationModule/RuleEngineSpenderDispatchCommon` | 11 | 9 | 0 | 0 | 2 |
| `PauseModuleCommon` | 15 | 12 | 2 | 1 | 0 |
| `AuthorizationModule/AuthorizationModuleCommon` | 5 | 3 | 2 | 0 | 0 |
| `standard/modules/RuleEngineMockStatefulRule` | 2 | 0 | 0 | 0 | 2 |
| `AllowlistModuleCommon` | 36 | 24 | 11 | 1 | 0 |
| `DocumentModule/DocumentModuleCommon` | 13 | 12 | 0 | 0 | 1 |
| `ExtraInfoModuleCommon` | 8 | 8 | 0 | 0 | 0 |
| `DebtModule/DebtModuleCommon` | 5 | 5 | 0 | 0 | 0 |
| `SnapshotModuleCommon/SnapshotModuleSetSnapshotEngineCommon` | 6 | 4 | 0 | 0 | 2 |
| `VersionModuleCommon` | 1 | 1 | 0 | 0 | 0 |
| `CMTATIntegrationCommon` | 4 | 3 | 1 | 0 | 0 |
| `proxy/general` (upgrades) | 10 | 2 | 1 | 1 | 6 |
| `deployment/*` (constructor behaviour) | 13 | 7 | 4 | 0 | 2 |
| **Total** | **343** | **274** | **42** | **10** | **17** |

### Families not ported

These families cover modules outside release 1 (see the README). Their 142 cases are not mapped.

| Family | Cases | Reason |
|---|---:|---|
| `CCIPModuleCommon`, `ERC20CrossChainModuleCommon` | 3 + 32 | Cross-chain is out of scope |
| `DebtModule/DebtEngineModuleCommon`, `DebtModuleSetDebtEngineCommon` | 3 + 4 | DebtEngine is out of scope |
| `DocumentModule/DocumentModuleSetDocumentEngineCommon` | 10 | DocumentEngine is out of scope; documents are stored in the token (ERC-1643) |
| `ERC7551ModuleCommon` | 6 | The ERC-7551 module is out of scope. The ERC-7551 *enforcement* overloads are ported |
| `HolderListModuleCommon` | 24 | HolderList is out of scope |
| `MetaTxModuleCommon`, `MetaTxMsgDataCommon`, `MulticallModuleCommon` | 2 + 2 + 2 | ERC-2771 is not ported. Starknet accounts batch calls natively |
| `PermitModuleCommon` | 8 | Permit is out of scope |
| `SnapshotModuleCommon/*` scheduling (GetNext, Scheduling, Rescheduling, Unschedule, global) | 46 | These test snapshot scheduling inside the SnapshotEngine, which lives outside the token. The token-side callback is covered by `snapshot` and `snapshot_preset` |

## Open items

These are the gaps and partials worth closing, most important first. The ids are referenced from the tables below.

1. ~~**P1: plain ERC-20 insufficient balance.**~~ Closed. `transfer`, `transfer_from`, `burn`, `batch_burn` and `batch_transfer` now assert OpenZeppelin's `'ERC20: insufficient balance'`, with atomicity for the batch calls.
2. ~~**P2: batch paths under pause and deactivation.**~~ Closed. The validation matrix now runs `batch_mint`, `batch_burn` and `burn_and_mint` on every preset, in every pause and freeze state.
3. ~~**P3: allowlist on batch and `transfer_from` paths.**~~ Closed. `allowlist` now covers `batch_mint`, `batch_burn`, `batch_transfer` and `transfer_from` with unlisted parties, an unlisted minter or burner, and a zero-value transfer.
4. ~~**P4: RuleEngine on batch paths.**~~ Closed. A rejecting engine is now tested on `transfer_from`, `batch_mint` and `batch_transfer` with full revert data. Dispatch is checked for `batch_burn` and `burn_self`, and the mint rejection now checks the full data.
5. ~~**P5: RuleEngine read path.**~~ Closed. The recorder's reads now depend on their arguments (a blocked address, a maximum value). Tests show that mint- and burn-shaped reads, the spender and the value all reach the engine, and that detect returns 0 when the engine allows.
6. ~~**P6: active-balance edge cases.**~~ Closed. Covered: minting above a frozen amount, reads at a non-zero active balance and one above it, zero-value reads when fully frozen, `set_frozen_tokens` to 0 and to the same non-zero value, `set_frozen_tokens(ZERO, 0)` check order, and zero-address checks on the with-data variants.
7. **P7: allowance edge cases.**
   - `approve(0)` while deactivated.
   - `approve(0)` after the spender is removed from the allowlist (NM-3).
   - Overwriting a non-zero allowance with another non-zero value.
   - `transfer_from` of zero with no allowance, `transfer_from` to self, and spending an allowance exactly.
8. ~~**P8: reentrancy with partial freeze.**~~ Closed by `rule_engine::reentrant_engine_cannot_move_frozen_tokens`.
9. **P9: upgrade coverage.**
   - Upgrade and migrate a Snapshot or Debt preset, then check `snapshot_engine()` is kept and still notified.
   - Check `information()` and `terms()` after an upgrade.
   - Deploy a preset with `admin = 0` (today only the access mock tests this).
10. **P10: events and argument order (minor).**
    - The `Spend` value when a forced transfer caps the spend, and no `Spend` when the allowance is infinite.
    - The unfreeze `AddressFrozen` event with data.
    - Role checks running before empty-array checks in batch freeze.
    - Empty-accounts checks running before length-mismatch checks.
    - Length mismatch in both directions for every batch call.
    - Per-account events for a batch allowlist update.
    - Re-enabling the allowlist.
    - `RoleRevoked`, and handing over the admin role.
    - Transfers working again after unpause.
    - Zero-value and self `Transfer` events.
    - `batch_balance_of` with an empty span.
    - `set_rule_engine` and `set_snapshot_engine` from zero to zero.

`src/mocks/rule_engine.cairo` (`WhitelistRuleEngine`) and `src/mocks/snapshot_engine.cairo` (`SimpleSnapshotEngine`) are legacy samples that no test uses.

---

## Case tables

### ERC20MintModuleCommon

| CMTAT case | Status | Cairo test(s) | Note |
|---|---|---|---|
| testCanBeMintedByAdmin | covered | `preset_events::run_core`, `mint::mint_increases_balance_and_supply` | |
| testCanMintByANewMinter | covered | `mint::mint_increases_balance_and_supply` | |
| testCanBeMintedWithReasonByAdmin | covered | `mint::mint_with_data_emits_data` | |
| testCanMintWithReasonByANewMinter | covered | `mint::mint_with_data_emits_data` | |
| testCannotMintByNonMinter | covered | `mint::mint_requires_minter_role`, `presets::core_calls_require_roles` | |
| testCanBeMintedEvenIfContractIsPaused | partial | `mint::mint_succeeds_while_paused`, `matrix` (paused) | Events and supply not checked |
| testCannotBeMintedIfContractIsDeactivated | covered | `mint::mint_reverts_when_deactivated`, `matrix` | |
| testCannotBeMintedIfToIsFrozen | covered | `mint::mint_reverts_when_recipient_frozen`, `matrix` | |
| testFrozenMinterCanStillMint | covered | `mint::mint_by_frozen_minter_succeeds` | |
| testFrozenMinterCanStillBatchMint | covered | `mint::batch_mint_by_frozen_minter_succeeds` | |
| testMintPropagatesSpenderToRuleEngine | covered | `rule_engine::mint_passes_minter_as_spender`, `rejecting_engine_reverts_mint` | |
| testMintWithRuleEngineAuthorizedSpenderCanMint | covered | `rule_engine::mint_passes_minter_as_spender` | |
| testCanBeMintedBatchByAdmin | covered | `mint::batch_mint_emits_batch_event_not_per_account_mint` | |
| testCanBeMintBatchedByANewMinter | covered | same | |
| testBatchMintPropagatesSpenderToRuleEngine | covered | `rule_engine::batch_mint_calls_engine_per_account`, `rejecting_engine_reverts_batch_mint` | |
| testBatchMintWithRuleEngineAuthorizedSpenderCanMint | covered | `rule_engine::batch_mint_calls_engine_per_account` | |
| testCannotBatchMintByNonMinter | covered | `mint::batch_mint_requires_minter_role` | |
| testCannotBatchMintIfLengthMismatchMissingAddresses | gap | | P10 |
| testCannotBatchMintIfLengthMismatchTooManyAddresses | covered | `mint::batch_mint_rejects_length_mismatch` | |
| testCannotBatchMintIfTOSIsEmpty | covered | `mint::batch_mint_rejects_empty_accounts` | |
| testCanBeMintedBatchEvenIfContractIsPaused | covered | `matrix` (paused, `BATCH_MINT`) | |
| testCannotBeBatchMintedIfContractIsDeactivated | covered | `matrix` (deactivated, `BATCH_MINT`) | |
| testCannotBeBatchMintedIfToIsFrozen | covered | `mint::batch_mint_is_atomic_on_frozen_recipient` | |
| testbatchTransfer | covered | `mint::batch_transfer_moves_minter_tokens` | |
| testCannotBatchTransferMoreTokensThanOwn | covered | `mint::batch_transfer_is_atomic_on_insufficient_balance`, `batch_transfer_respects_active_balance` | |
| testCannotBatchTransferIfLengthMismatchMissingAddresses | covered | `mint::batch_transfer_rejects_length_mismatch` | |
| testCannotBatchTransferIfLengthMismatchTooManyAddresses | gap | | P10 |
| testCannotBatchTransferIfTOSIsEmpty | covered | `mint::batch_transfer_rejects_empty_tos` | |
| testCannotBeBatchTransferIfContractIsPaused | covered | `mint::batch_transfer_reverts_when_paused`, `matrix` | |
| testCannotBeBatchMTransferIfContractIsDeactivated | covered | `matrix` (deactivated, `BATCH_TRANSFER`) | Pause error, as in CMTAT |
| testCannotBeBatchTransferIfToIsFrozen | covered | `mint::batch_transfer_reverts_when_recipient_frozen`, `matrix` | |
| testCannotBatchTransferIfMinterIsFrozen | covered | `mint::batch_transfer_reverts_when_minter_frozen`, `matrix` | |
| testBatchTransferPropagatesSpenderToRuleEngine | covered | `rule_engine::batch_transfer_passes_minter_as_spender_and_from` | |
| testBatchTransferWithRuleEngineAuthorizedSpenderCanTransfer | covered | same | |

### ERC20BurnModuleCommon

| CMTAT case | Status | Cairo test(s) | Note |
|---|---|---|---|
| testCanBeBurntByAdmin | covered | `burn::burn_with_data_emits_data`, `preset_events::run_core` | |
| testCanBeBurntByAdminWithoutReason | covered | `burn::burn_reduces_balance_and_supply`, `preset_events::run_core` | |
| testCanBeBurntByBurnerRole | covered | `burn::burn_reduces_balance_and_supply` | |
| testCannotBeBurntWithoutBurnerRole | covered | `burn::burn_requires_burner_role`, `presets::core_calls_require_roles` | |
| testCannotBeBurntIfBalanceExceeds | covered | `burn::burn_above_balance_reverts_with_insufficient_balance` | |
| testCannotBeBurnIfContractIsDeactivated | covered | `burn::burn_reverts_when_deactivated`, `matrix` | |
| testCanBeBurnEvenIfContractIsPaused | partial | `burn::burn_succeeds_while_paused`, `matrix` | Events and supply not checked |
| testCannotBeBurnIfAddressIsFrozen | covered | `burn::burn_reverts_when_account_frozen`, `matrix` | |
| testBurnPropagatesSpenderToRuleEngine | covered | `rule_engine::burn_passes_burner_as_spender` | |
| testBurnWithRuleEngineAuthorizedSpenderCanBurn | covered | same | |
| testCanBurnAndMint | covered | `burn::burn_and_mint_with_both_roles` | |
| testCannotBurnAndMintWithoutMinterRole | covered | `burn::burn_and_mint_requires_minter_role_for_mint_leg` | |
| testCannotBurnAndMintWithoutBurnerRole | covered | `burn::burn_and_mint_requires_burner_role_for_burn_leg` | |
| testCannotBeBurnAndMintIfContractIsDeactivated | covered | `matrix` (deactivated, `BURN_AND_MINT`) | |
| testCanBeBurnAndMintEvenIFContractIsPaused | covered | `matrix` (paused, `BURN_AND_MINT`) | |
| testCanBeBurntBatchByAdmin | covered | `burn::batch_burn_with_data_emits_data` | |
| testCanBeBurntBatchByAdminWithoutReason | covered | `burn::batch_burn_emits_batch_event_not_per_account_burn` | |
| testCanBeBurntBatchByBurnerRoleWithoutReason | covered | same | |
| testCanBeBurntBatchByBurnerRole | covered | `burn::batch_burn_with_data_emits_data` | |
| testCannotBeBurntBatchWithoutBurnerRole | gap | | P10 |
| testCannotBeBurntBatchIfOneBalanceExceeds | covered | `burn::batch_burn_is_atomic_on_insufficient_balance` | |
| testCannotBatchBurnIfLengthMismatchMissingAddresses | covered | `burn::batch_burn_rejects_length_mismatch` | |
| testCannotBatchBurnIfLengthMismatchTooManyAddresses | gap | | P10 |
| testCannotBatchBurnIfAccountsIsEmpty | covered | `burn::batch_burn_rejects_empty_accounts` | |
| testCanBeBatchBurnEvenIfContractIsPaused | covered | `matrix` (paused, `BATCH_BURN`) | |
| testCannotBeBatchBurnIfContractIsDeactivated | covered | `matrix` (deactivated, `BATCH_BURN`) | |
| testCannotBeBatchBurnIfToIsFrozen | covered | `burn::batch_burn_is_atomic_on_frozen_account` | |
| testCanBatchBurnWithExactBalances | gap | | P10 |
| testBatchBurnPropagatesSpenderToRuleEngine | covered | `rule_engine::batch_burn_calls_engine_per_account` | |
| testBatchBurnWithRuleEngineAuthorizedSpenderCanBurn | covered | `rule_engine::batch_burn_calls_engine_per_account` | |

### ERC20BaseModuleCommon

| CMTAT case | Status | Cairo test(s) | Note |
|---|---|---|---|
| testHasTheDefinedName | covered | `presets::deployment_defaults` | |
| testHasTheDefinedSymbol | covered | `presets::deployment_defaults` | |
| testDecimalsEqual0 | covered | `presets::deployment_defaults` | |
| testAdminCanUpdateName | covered | `attributes::set_name_updates_metadata_and_emits`, `preset_events::run_core` | |
| testCannotNonAdminUpdateName | covered | `attributes::set_name_and_symbol_require_default_admin` | |
| testCannotApproveIfPaused | covered | `erc20_base::approve_reverts_when_paused` | |
| testCannotApproveIfOwnerIsFrozen | covered | `erc20_base::approve_reverts_when_owner_frozen` | |
| testCannotApproveIfSpenderIsFrozen | covered | `erc20_base::approve_reverts_when_spender_frozen` | |
| testAdminCanUpdateSymbol | covered | `attributes::set_symbol_updates_metadata_and_emits` | |
| testCannotNonAdminUpdateSymbol | covered | `attributes::set_name_and_symbol_require_default_admin` | |
| testHasTheCorrectBalanceBatch | partial | `erc20_base::batch_balance_of_returns_balances_and_total_supply` | Empty input not tested (P10) |
| testApproveAllowance | covered | `preset_events::run_core` | |
| testRedefinedAllowanceWithApprove | partial | `erc20_base::approve_zero_is_always_allowed` | Overwrite from one non-zero value to another not tested (P7) |
| testApproveZeroValue | partial | `erc20_base::approve_zero_is_always_allowed` | `Approval(…, 0)` event not checked |
| testTransferFromOneAccountToAnother | covered | `erc20_base::transfer_moves_balance_and_emits_transfer_only` | |
| testCannotTransferMoreTokensThanOwn | covered | `erc20_base::transfer_above_balance_reverts_with_insufficient_balance` | |
| testCanTransferZeroValue | partial | `erc1404::zero_value_with_fully_frozen_balance_is_allowed` | Event and balances not checked (P10) |
| testCanTransferToSelf | partial | `snapshot::self_transfer_reports_unchanged_balance` | Event and balance not checked (P10) |
| testTransferByAnotherAccountWithTheRightAllowance | covered | `erc20_base::transfer_from_spends_allowance_and_emits_spend_without_approval` | |
| testCannotTransferByAnotherAccountWithInsufficientAllowance | covered | `erc20_base::transfer_from_rejects_insufficient_allowance` | |
| testCannotTransferByAnotherAccountWithInsufficientBalance | covered | `erc20_base::transfer_from_above_balance_reverts_with_insufficient_balance` | |
| transferFrom: testTransferFromOneAccountToAnother | covered | `erc20_base::transfer_from_spends_allowance_and_emits_spend_without_approval` | |
| transferFrom: testCannotTransferMoreTokensThanOwn | covered | `erc20_base::transfer_from_above_balance_reverts_with_insufficient_balance` | |
| transferFrom: testCanTransferFromZeroValue | gap | | P7 |
| transferFrom: testCanTransferFromToSelf | gap | | P7 |

### ERC20EnforcementModuleCommon

| CMTAT case | Status | Cairo test(s) | Note |
|---|---|---|---|
| ForceTransfer as admin | covered | `erc20_enforcement::forced_transfer_within_active_balance_keeps_frozen` | |
| …AndUnfreezeTokens | covered | `erc20_enforcement::forced_transfer_unfreezes_only_shortfall`, `fuzz` | |
| …WithoutUnfreezeTokens | covered | `erc20_enforcement::forced_transfer_within_active_balance_keeps_frozen` | |
| ForceTransferBurn AndUnfreezeTokens | covered | `erc20_enforcement::forced_transfer_to_zero_burns`, `fuzz::forced_transfer_unfreezes_only_shortfall` | |
| …AndReduceAllowanceToZero | partial | `erc20_enforcement::forced_transfer_caps_allowance_spend_at_allowance` | Capped `Spend` value not checked (P10) |
| …AndReduceAllowance | covered | `erc20_enforcement::forced_transfer_spends_recipient_allowance` | |
| ForcedTransferWithoutAllowanceDoesNotEmitSpend | covered | `erc20_enforcement::forced_transfer_within_active_balance_keeps_frozen` | Asserts no other event |
| ForcedTransferWithInfiniteAllowanceDoesNotEmitSpend | partial | `erc20_enforcement::forced_transfer_keeps_infinite_allowance` | No-`Spend` not asserted (P10) |
| ForceBurnWithForceTransferAsAdmin | covered | `erc20_enforcement::forced_transfer_to_zero_burns`, `matrix` | |
| …AsAdminWithoutReason | covered | `erc20_enforcement::forced_transfer_within_active_balance_keeps_frozen` | |
| CannotForceTransfer…IfBalanceNotEnough | covered | `erc20_enforcement::forced_transfer_rejects_exceeding_balance` | |
| CannotForceTransferToTheSameAddress | covered | `erc20_enforcement::forced_transfer_to_self_reverts_and_keeps_frozen` | |
| CannotNonAdminTransferFunds | covered | `erc20_enforcement::forced_transfer_requires_default_admin` | |
| Freeze: AdminCanFreezeAddress | covered | `erc20_enforcement::freeze_partial_tokens_accumulates_and_emits`, `preset_events::run_common` | |
| Freeze: AdminCanFreezeAddressTwice | covered | `erc20_enforcement::freeze_partial_tokens_accumulates_and_emits` | |
| Freeze: EnforcerRoleCanFreezeAddress | covered | same | |
| Freeze: AdminCanUnfreezeAddress | covered | `erc20_enforcement::unfreeze_partial_tokens_reduces_and_emits`, `fuzz` | |
| Freeze: AdminCanUnfreezeAddressAndTransferMoreActiveBalance | partial | `erc20_enforcement::unfreeze_partial_tokens_with_data_emits_data` | `can_transfer` above the balance after a full unfreeze not checked (P10) |
| Freeze: AdminCanUnfreezeAddressTwice | partial | `erc20_enforcement::unfreeze_partial_tokens_reduces_and_emits` | Only one unfreeze (P10) |
| Freeze: EnforcerRoleCanUnfreezeAddress | covered | `erc20_enforcement::unfreeze_partial_tokens_reduces_and_emits` | |
| Freeze: Admin/EnforcerCanFreezeAddressReason (2) | covered | `erc20_enforcement::freeze_partial_tokens_with_data_emits_data` | |
| Freeze: Admin/EnforcerCanUnfreezeAddressReason (2) | covered | `erc20_enforcement::unfreeze_partial_tokens_with_data_emits_data` | |
| Freeze: CannotNonEnforcerFreezeAddress | covered | `erc20_enforcement::freeze_partial_tokens_requires_erc20_enforcer` | |
| Freeze: CannotNonEnforcerUnfreezeAddress | covered | `erc20_enforcement::unfreeze_partial_tokens_requires_erc20_enforcer` | |
| Freeze: CannotFreezeZeroAddress | covered | `erc20_enforcement::freeze_partial_tokens_rejects_zero_address` | |
| Freeze: CannotUnfreezeZeroAddress | covered | `erc20_enforcement::unfreeze_partial_tokens_rejects_zero_address` | |
| Freeze: CannotFreezeZeroAddressWithReason | covered | `erc20_enforcement::with_data_freeze_and_unfreeze_reject_zero_address` | |
| Freeze: CannotFreezeMoreThanAvailableBalance | covered | `erc20_enforcement::freeze_partial_tokens_rejects_exceeding_balance` | |
| Freeze: CannotUnfreezeZeroAddressWithReason | covered | `erc20_enforcement::with_data_freeze_and_unfreeze_reject_zero_address` | |
| Freeze: CannotUnfreezeMoreThanFrozenBalance | covered | `erc20_enforcement::unfreeze_partial_tokens_rejects_exceeding_frozen`, `fuzz` | |
| Freeze: CannotTransferMoreThanActiveBalance | covered | `erc20_base::transfer_above_active_balance_reverts`, `fuzz`, `erc1404::messages_match_cmtat` | |
| Freeze: CanSetFrozenTokensGreaterThanBalance | covered | `erc20_enforcement::set_frozen_tokens_may_exceed_balance`, `matrix` | |
| Freeze: CanTransferZeroWhenFrozenTokensCoverBalance | covered | `erc1404::zero_value_with_fully_frozen_balance_is_allowed` | |
| Freeze: CanSetFrozenTokensToZeroFromNonZero | covered | `erc20_enforcement::set_frozen_tokens_to_zero_unfreezes_everything` | |
| Freeze: CanForcedTransferWhenFrozenTokensGreaterThanBalance | covered | `matrix` (`FORCED_TRANSFER`, partially frozen) | |
| Freeze: CanMintToAccountAfterFrozenTokensGreaterThanBalance | covered | `erc1404::mint_to_account_frozen_above_balance` | |
| Freeze: CannotSetFrozenTokensOnZeroAddress | covered | `erc20_enforcement::set_frozen_tokens_rejects_zero_address` | |
| Freeze: SetFrozenTokensOnZeroAddressCannotBrickMint | covered | `erc20_enforcement::set_frozen_tokens_rejects_zero_address` | Implied by the revert |
| Freeze: SetFrozenTokensOnZeroAddressCannotBrickBatchMint | covered | same | Implied by the revert |
| Freeze: CannotSetFrozenTokensOnZeroAddressEvenToZero | covered | `erc20_enforcement::set_frozen_tokens_rejects_zero_address_even_to_zero` | |
| Freeze: SetFrozenTokensStillWorksOnRegularAddress | covered | `erc20_enforcement::set_frozen_tokens_increase_emits_difference`, `fuzz` | |
| Freeze: CanTransferTokenIfActiveBalanceIsEnough | covered | `erc20_base::transfer_up_to_active_balance_succeeds`, `erc1404::reads_at_nonzero_active_balance_boundary` | |
| Freeze: CannotTransferFromTokenIfActiveBalanceIsNotEnough | covered | `erc20_base::transfer_from_above_active_balance_reverts`, `matrix` | |
| Set: AdminCanFreezeAddress | covered | `erc20_enforcement::set_frozen_tokens_increase_emits_difference` | |
| Set: AdminCanFreezeAddressWithTokenFrozen | covered | `erc20_enforcement::set_frozen_tokens_rejects_same_nonzero_value` | |
| Set: …WithTokenFrozenDifferentLess | covered | `erc20_enforcement::set_frozen_tokens_decrease_emits_difference` | |
| Set: …WithTokenFrozenDifferentMore | covered | `erc20_enforcement::set_frozen_tokens_increase_emits_difference` | |
| Set: EnforcerRoleCanFreezeAddress | covered | same | |
| Set: AdminCanUnfreezeAddress | covered | `erc20_enforcement::set_frozen_tokens_decrease_emits_difference` | |
| Set: EnforcerRoleCanUnfreezeAddress | covered | same | |
| Set: CannotNonEnforcersetFrozenTokens | covered | `erc20_enforcement::set_frozen_tokens_requires_erc20_enforcer` | |
| Set: CannotTransferMoreThanActiveBalance | covered | `matrix` (partially frozen) | |
| Set: CanTransferTokenIfActiveBalanceIsEnough | covered | `erc1404::reads_at_nonzero_active_balance_boundary` | Frozen amount set with `set_frozen_tokens` |
| Set: CannotTransferFromTokenIfActiveBalanceIsNotEnough | covered | `matrix` | |

### ERC20EnforcementERC7551ModuleCommon

| CMTAT case | Status | Cairo test(s) | Note |
|---|---|---|---|
| ForcedTransferWithReasonEmitsReasonedEvent | covered | `erc20_enforcement::forced_transfer_with_data_carries_data` | |
| FreezeWithReasonEmitsReasonedEvent | covered | `erc20_enforcement::freeze_partial_tokens_with_data_emits_data` | |
| UnfreezeWithReasonEmitsReasonedEvent | covered | `erc20_enforcement::unfreeze_partial_tokens_with_data_emits_data` | |
| GetActiveBalanceOf | covered | `erc20_enforcement::active_balance_is_balance_minus_frozen`, `standard::has_erc7551_enforcement_overloads` | |

### EnforcementModuleCommon

| CMTAT case | Status | Cairo test(s) | Note |
|---|---|---|---|
| AdminCanFreezeAddress | covered | `enforcement::admin_can_freeze`, `preset_events`, `matrix` | |
| AdminCanBatchFreezeAddress | covered | `enforcement::batch_freeze_sets_each_status_and_emits_per_account` | |
| AdminCanBatchPartialFreezeAddress | covered | same | |
| EnforcerRoleCanFreezeAddress | covered | `enforcement::freeze_with_data_emits_data` | |
| AdminCanUnfreezeAddress | partial | `enforcement::freeze_and_unfreeze` | Unfreeze event with data not checked (P10) |
| EnforcerRoleCanUnfreezeAddress | partial | `enforcement::freeze_and_unfreeze` | Same |
| CannotNonEnforcerFreezeAddress | covered | `enforcement::freeze_requires_enforcer_role`, `freeze_with_data_requires_enforcer_role` | |
| CannotNonEnforcerBatchFreezeAddress | partial | `enforcement::batch_freeze_requires_enforcer_role` | Role check before the empty check not pinned (P10) |
| CannotNonEnforcerUnfreezeAddress | partial | `enforcement::freeze_requires_enforcer_role` | Unfreeze direction not tested |
| CannotFreezeZeroAddress | covered | `enforcement::freeze_with_data_rejects_zero_address` | |
| CannotFreezeZeroAddressWithoutReason | covered | `enforcement::freeze_rejects_zero_address` | |
| CannotBatchFreezeZeroAddress | covered | `enforcement::batch_freeze_rejects_zero_address_atomically` | |
| CannotTransferWhenFromIsFrozenWithTransfer | covered | `matrix`, `erc20_base::transfer_reverts_when_sender_frozen` | |
| CannotTransferTokenWhenToIsFrozenWithTransferFrom | covered | `matrix` | |
| CanRevokeAllowanceWhenSpenderIsFrozen | covered | `erc20_base::approve_zero_is_always_allowed` | |
| CanRevokeAllowanceWhenOwnerIsFrozen | covered | same | |
| CannotGrantAllowanceWhenSpenderIsFrozen | covered | `erc20_base::approve_reverts_when_spender_frozen` | |
| CannotTransferTokenWhenSpenderIsFrozenWithTransferFrom | covered | `matrix`, `erc20_base::transfer_from_reverts_when_spender_frozen` | |
| ReasonParameterCanBeEmptyString | covered | `enforcement::freeze_emits_event_with_empty_data` | |
| CannotBatchFrozenIfLengthMismatchTooManyAddresses | covered | `enforcement::batch_freeze_rejects_length_mismatch` | |
| CannotBatchFrozenIfAccountsIsEmpty | partial | `enforcement::batch_freeze_rejects_empty_accounts` | Empty-accounts error over length mismatch not pinned (P10) |

### ValidationModule families

| CMTAT case | Status | Cairo test(s) | Note |
|---|---|---|---|
| Common: testCanReturnTheRightAddressIfSet | covered | `standard::constructor_sets_rule_engine` | |
| Common: testCanTransferWithoutRuleEngine | covered | `rule_engine::set_rule_engine_to_zero_removes_engine`, `matrix` | |
| Common: testCanDetectTransferRestrictionValidTransfer | covered | `rule_engine::reads_pass_value_to_engine` | |
| Common: testCanReturnMessageValidTransfer | covered | `erc1404::messages_match_cmtat` | |
| Common: testCanDetectTransferRestrictionWithAmountTooHigh | covered | `rule_engine::detect_falls_back_to_engine_code` | Configured code |
| Common: testCanReturnMessageWithAmountTooHigh | covered | same | |
| Common: testCanReturnMessageWithUnknownRestrictionCode | covered | same | |
| Common: testCanTransferAllowedByRule | partial | `rule_engine::transfer_calls_erc3643_transferred_without_spender` | Balances not checked |
| Common: testCannotTransferIfNotAllowedByRule | covered | `rule_engine::rejecting_engine_reverts_transfer` | |
| Common: testCannotBatchTransferIfNotAllowedByRule | covered | `rule_engine::rejecting_engine_reverts_batch_transfer` | |
| Common: testCanTransferFrom | covered | `rule_engine::from_reads_pass_spender_to_engine` | |
| Common: testCanTransferFromWithoutRuleEngine | covered | `matrix` | |
| Common: testCannotTransferFromIfNotAllowedByRuleEngine | covered | `rule_engine::rejecting_engine_reverts_transfer_from`, `can_transfer_consults_engine` | |
| Common: testCanApproveAllowedByRuleEngine | partial | `rule_engine::approve_does_not_call_engine` | No allowance or balance checks |
| Common: testCanMintWithoutRuleEngine | covered | `erc1404::can_transfer_mint_and_burn_ignore_pause` | |
| Common: testCanDetectTransferRestrictionValidTransfer (mint) | covered | `rule_engine::mint_and_burn_shaped_reads_reach_engine` | |
| Common: testCanDetectTransferRestrictionWitMintAmountTooHigh | covered | `rule_engine::mint_and_burn_shaped_reads_reach_engine`, `reads_pass_value_to_engine` | |
| Common: testCanReturnMessageWithMintAmountTooHigh | covered | `rule_engine::detect_falls_back_to_engine_code` | |
| Common: testCanMintAllowedByRule | partial | `rule_engine::mint_passes_minter_as_spender` | No balance or read checks |
| Common: testCannotMintIfNotAllowedByRule | covered | `rule_engine::rejecting_engine_reverts_mint`, `mint_and_burn_shaped_reads_reach_engine` | |
| Common: testCannotBatchMintIfNotAllowedByRule | covered | `rule_engine::rejecting_engine_reverts_batch_mint` | |
| Common: testCanTransferReturnsFalseForMintToFrozenAddress | covered | `erc1404::can_transfer_mint_and_burn_respect_deactivation_and_freeze` | |
| Common: testCanTransferReturnsFalseForBurnFromFrozenAddress | covered | same | |
| Common: testCanSend/CanReceive true/false (4) | covered | `matrix` (read checks) | |
| Core: testCanTransferWithoutRuleEngine | covered | `matrix` (Light) | |
| Core: testCanDetectTransferRestrictionValidTransfer | covered | `matrix` (Light) | |
| Core: testCanTransferAllowed, testCanTransfer | covered | `matrix` (Light), `erc20_base::transfer_moves_balance_and_emits_transfer_only` | |
| SetRuleEngine: testCanReturnTheRightInterface | n/a | | Tests the Solidity mock's ERC-165 ids |
| SetRuleEngine: testCanBeSetByAdmin | covered | `rule_engine::set_rule_engine_stores_and_emits` | |
| SetRuleEngine: testCanNotBeSetByAdminWithTheSameValue | partial | `rule_engine::set_rule_engine_rejects_same_value` | Zero to zero not tested (P10) |
| SetRuleEngine: testCannotBeSetByNonAdmin | covered | `rule_engine::set_rule_engine_requires_default_admin` | |
| SetRuleEngine: testCanReturnMessageWithNoRuleEngineAndUnknownRestrictionCode | covered | `erc1404::messages_match_cmtat` | |
| SetRuleEngine: testCanDetectTransferRestrictionValidTransferWithoutRuleEngine | covered | `matrix` | |
| Reentrancy: testFrozenTokensCannotBeDrainedByReentrantRuleEngine | covered | `rule_engine::reentrant_engine_cannot_move_frozen_tokens` | Whole call reverts (no `try`/`catch`) |
| Reentrancy: testReentrantRuleEngineCallbackIsRejected | n/a | | Engine catching a failed reentry needs `try`/`catch` |
| Reentrancy: testReentrantCallRevertsWithDedicatedError | covered | `rule_engine::reentrant_engine_is_rejected`, `reentrant_engine_cannot_move_frozen_tokens` | |
| Reentrancy: testReentrancyIsAlsoBlockedOnTransfer | covered | `rule_engine::reentrant_engine_is_rejected` | |
| Reentrancy: testNonReentrantRuleEngineTransferStillWorks | partial | `rule_engine::transfer_from_passes_spender` | No freeze or balance checks |
| Reentrancy: testConsecutiveTransfersAreNotBlockedByTheGuard | covered | `rule_engine::guard_is_released_after_each_call` | |
| Reentrancy: testBatchOperationsAreNotBlockedByTheGuard | covered | `rule_engine::batch_mint_calls_engine_per_account` | |
| Dispatch: transfer_from, transfer, mint, batch_mint, burn, burn_from, batch_transfer (7) | covered | `rule_engine::{transfer_from_passes_spender, transfer_calls_erc3643_transferred_without_spender, mint_passes_minter_as_spender, batch_mint_calls_engine_per_account, burn_passes_burner_as_spender, burn_from_passes_caller_as_spender, batch_transfer_passes_minter_as_spender_and_from}` | |
| Dispatch: testBatchBurnUsesSpenderAwareOverloadWithOperator | covered | `rule_engine::batch_burn_calls_engine_per_account` | |
| Dispatch: testSelfBurnUsesSpenderAwareOverloadWithHolder | covered | `rule_engine::burn_self_passes_holder_as_spender` | |
| Dispatch: crosschain mint and burn (2) | n/a | | Cross-chain is out of scope |
| StatefulRule (2) | n/a | | Tests a Solidity mock's holder tracker (HolderList) |

### PauseModuleCommon and AuthorizationModuleCommon

| CMTAT case | Status | Cairo test(s) | Note |
|---|---|---|---|
| testCanBePausedByAdmin | covered | `pause::admin_can_pause`, `preset_events::run_core` | |
| testCanBePausedByPauserRole | covered | `pause::pause_by_pauser_emits_event` | |
| testCannotBePausedByNonPauser | covered | `pause::pause_requires_pauser_role` | |
| testCanBeUnpausedByAdmin | partial | `preset_events::run_core` | Transfer after unpause not checked (P10) |
| testCanBeUnpausedByANewPauser | partial | `pause::unpause_by_pauser_emits_event` | Same |
| testCannotBeUnpausedByNonPauser | covered | `pause::unpause_requires_pauser_role` | |
| testCannotTransferTokenWhenPausedWithTransfer | covered | `matrix` (paused), `erc1404::messages_match_cmtat` | |
| testCanRevokeAllowanceWhenPaused | covered | `erc20_base::approve_zero_is_always_allowed` | |
| testCannotGrantAllowanceWhenPaused | covered | `erc20_base::approve_reverts_when_paused` | |
| testCanRevokeAllowanceWhenDeactivated | gap | | P7 |
| testCannotTransferTokenWhenPausedWithTransferFrom | covered | `matrix`, `erc20_base::transfer_from_reverts_when_paused` | |
| testCanDeactivatedByAdminIfContractIsPaused | covered | `pause::deactivate_by_admin_emits_event`, `unpause_after_deactivation_reverts`, `matrix` | |
| testCannotDeactivatedIfNotInPause | covered | `pause::deactivate_requires_pause` | |
| testCannotBeDeactivatedByNonAdmin | covered | `pause::deactivate_requires_default_admin` | |
| testCannotBeDeactivatedTwice | covered | `pause::deactivate_twice_reverts` | |
| Auth: testAdminCanTransmitAdminship | partial | `access::revoking_admin_removes_implicit_roles` | No renounce or new-admin flow (P10) |
| Auth: testAdminCanGrantRole | covered | `access::grant_role_emits_event` | |
| Auth: testAdminCanRevokeRole | partial | `access::revoke_role_removes_role` | `RoleRevoked` not checked (P10) |
| Auth: testCannotNonAdminGrantRole | covered | `access::grant_role_requires_role_admin` | |
| Auth: testCannotNonAdminRevokeRole | covered | `access::revoke_role_requires_role_admin` | |

### AllowlistModuleCommon

| CMTAT case | Status | Cairo test(s) | Note |
|---|---|---|---|
| AdminCanAllowlistAddress | covered | `allowlist::set_address_allowlist_emits`, `presets::admin_holds_every_role` | |
| AdminCanAllowlistAddressWithoutReason | covered | `allowlist::set_address_allowlist_emits` | |
| AdminCanBatchAllowlistAddress | partial | `allowlist::batch_set_address_allowlist_sets_each` | Per-account events not checked (P10) |
| AdminCanBatchPartialAllowlistAddress | partial | same | Same |
| ReasonParameterCanBeEmptyString | covered | `allowlist::set_address_allowlist_emits` | |
| EnforcerRoleCanAllowlistAddress | covered | same | |
| AdminCanEnableAllowlistAddress | partial | `allowlist::enable_allowlist_emits` | Re-enable not tested (P10) |
| AdminCanUnAllowlistAddress | covered | `allowlist::set_address_allowlist_with_data_emits_data` | |
| EnforcerRoleCanUnAllowlistAddress | covered | same | |
| CannotNonEnforcerAllowlistAddress | covered | `allowlist::management_requires_allowlist_role` | |
| CannotNonEnforcerBatchAllowlistAddress | covered | same | |
| CannotNonEnforcerRemoveFromAllowlistAddress | partial | same | Removing an address not tested |
| CannotTransferWhenFromIsNotAllowlist | covered | `allowlist::transfer_from_unlisted_sender_reverts` | |
| CanTransferMatrix listed/listed | covered | `allowlist::can_transfer_reflects_allowlist` | |
| CanTransferMatrix listed/unlisted | covered | same | |
| CanTransferMatrix unlisted/listed | partial | `allowlist::transfer_from_unlisted_sender_reverts` | Reads not checked |
| CanTransferMatrix unlisted/unlisted | gap | | P10 |
| ZeroValueTransferRequiresSenderAndReceiverAllowlisted | covered | `allowlist::zero_value_transfer_requires_listing` | |
| CannotApproveWhenOwnerIsNotAllowlisted | covered | `allowlist::approve_requires_listed_owner_and_spender` | |
| CanRevokeAllowanceWhenSpenderIsNotAllowlisted | partial | same | Revoked with the owner unlisted, not the spender (P7) |
| CannotApproveWhenSpenderIsNotAllowlisted | covered | same | |
| CannotMintToNoAllowlistAddress | partial | `allowlist::mint_to_unlisted_reverts` | Read not checked |
| CannotBatchMintToNoAllowlistAddress | covered | `allowlist::batch_mint_to_unlisted_reverts` | |
| MinterNotAllowlistedCanStillMint | covered | `allowlist` (setup) | Implicit |
| MinterNotAllowlistedCanStillBatchMint | covered | `allowlist::unlisted_minter_can_batch_mint` | |
| CanForceTransfer…WithoutUnfreezeTokens | partial | `allowlist::forced_transfer_ignores_allowlist`, `matrix` | Not combined with frozen tokens |
| CanBatchBurnIfAllowlistedAddress | covered | `allowlist::unlisted_burner_can_batch_burn_listed_account` | |
| CannotBatchBurnFromNoAllowlistedAddress | covered | `allowlist::batch_burn_from_unlisted_reverts` | |
| CanBurnFromAllowlistedAddress | partial | `matrix` (allowlist) | Read not checked |
| CannotBurnFromRemoveFromAllowlistedAddress | partial | `allowlist::burn_from_unlisted_reverts` | Read not checked |
| CannotBeBatchTransferIfToIsNotAllowlisted | covered | `allowlist::batch_transfer_to_unlisted_reverts` | |
| CanTransferTokenWithTransferFrom | covered | `matrix` (allowlist), `allowlist::can_transfer_reflects_allowlist` | |
| CannotTransferTokenWhenToIsNotAllowlistWithTransferFrom | covered | `allowlist::transfer_from_to_unlisted_reverts` | |
| CannotTransferTokenWhenSpenderIsNotAllowlistWithTransferFrom | covered | `allowlist::transfer_from_requires_listed_spender` | |
| CannotBatchAllowlistIfLengthMismatchTooManyAddresses | partial | `allowlist::batch_set_address_allowlist_validates_input` | One direction only (P10) |
| CannotBatchAllowlistIfAccountsIsEmpty | covered | same | |

### Documents, extra information, debt, snapshot, version

| CMTAT case | Status | Cairo test(s) | Note |
|---|---|---|---|
| Document: CanReturnTheRightAddressIfSet | n/a | | DocumentEngine is out of scope |
| Document: other 12 cases | covered | `documents::*` (set, update, remove, compaction, roles, zero name, missing document, empty read), `standard::has_documents` | |
| ExtraInfo: all 8 cases | covered | `attributes::*`, `standard::constructor_sets_attributes_and_information` | |
| Debt: all 5 cases | covered | `debt::*`, `debt_preset::debt_is_managed_under_debt_role` | |
| Snapshot: CanInitializeWithSnapshotEngine | n/a | | The engine is set after deployment, not in the constructor |
| Snapshot: CanInitializeWithZeroSnapshotEngine | covered | `snapshot_preset::constructor_sets_rule_engine_and_no_snapshot_engine` | |
| Snapshot: CannotCallInitializeWithEnginesTwice | n/a | | A constructor runs once. The reinitializer is covered by `upgrade::migrate_runs_once` |
| Snapshot: CanBeSetByAdmin | covered | `snapshot::set_snapshot_engine_stores_and_emits`, `preset_events` | |
| Snapshot: CannotBeSetByAdminWithTheSameValue | covered | `snapshot::set_snapshot_engine_rejects_same_value` | Zero to zero not tested (P10) |
| Snapshot: CannotBeSetByNonAdmin | covered | `snapshot::set_snapshot_engine_requires_snapshooter_role` | |
| Version: HasTheDefinedVersion | covered | `attributes::version_is_cmtat_3_3_0`, `presets::deployment_defaults` | |

### Integration, upgrades, deployment

| CMTAT case | Status | Cairo test(s) | Note |
|---|---|---|---|
| Integration: SupportRightInterface | partial | `interface_ids::*_interfaces` | No unknown-id check |
| Integration: CMTATIntegration | covered | `preset_events::run_core` | ERC-7551 metadata and cross-chain parts are out of scope |
| Integration: AdminCanUpdateInformation | covered | `attributes::admin_can_set_extra_information` | |
| Integration: CanDeactivatedByAdminIfContractIsPaused | covered | `pause`, `erc1404::deactivated_code_1_but_transfer_reverts_with_pause`, `matrix` | |
| Upgrade: KeepStorageForTokens | covered | `upgrade::upgrade_and_migrate_keep_storage`, `presets::upgrade_requires_default_admin` | |
| Upgrade: MigrationCannotRunTwice | covered | `upgrade::migrate_runs_once`, `migrate_requires_default_admin`, `fresh_v2_deployment_cannot_migrate` | |
| Upgrade: UnchangedStateIsPreservedAcrossTheUpgrade | partial | `upgrade::upgrade_and_migrate_keep_storage` | `information()` and `terms()` not checked (P9) |
| Upgrade: SnapshotVariantKeepsTheSnapshotEngine | gap | | P9 |
| Upgrade: v3.2.0 fixture, name/symbol layout migration, DocumentEngine and SnapshotEngine removal (6) | n/a | | Specific to the Solidity v3.2.0 to v3.3.0 upgrade |
| Deployment: admin = 0 rejected (proxy, standalone) | partial | `access::initializer_rejects_zero_admin` | Tested on the access mock, not a preset (P9) |
| Deployment: Standard with or without a rule engine (2) | covered | `standard::constructor_without_rule_engine`, `constructor_sets_rule_engine` | |
| Deployment: CannotInitializeStandardProxyTwice | n/a | | Constructor |
| Deployment: ERC-721 mock | n/a | | Not ported |
| Deployment: Light SupportRightInterface | partial | `interface_ids::light_interfaces` | No unknown-id check |
| Deployment: Light forced burn (3) | covered | `forced_burn::*`, `matrix` (Light) | |
| Deployment: allowlist enabled at deployment | covered | `allowlist::enabled_at_deployment` | |
| Deployment: allowlist disabled, common suite | partial | `allowlist::disabled_allowlist_allows_unlisted` | Only transfer and `can_receive` checked |
| Deployment: common defaults | covered | `presets::deployment_defaults`, `admin_holds_every_role`, `optional_modules_match_cmtat_variant` | |

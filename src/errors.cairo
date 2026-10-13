// SPDX-License-Identifier: MPL-2.0
// CMTAT v3.3.0 error names as felt short strings.
//
// Names that fit in 31 characters are kept verbatim. Longer names use a short
// form: the `CMTAT_` prefix and `Module` suffix are dropped, the module name is
// abbreviated (`Enf` = Enforcement), and `length` / `Balance` become `Len` / `Bal`.
// The Solidity name is noted next to each short form.
//
// Errors that carry arguments in Solidity (e.g. `ERC7943CannotSend(account)`)
// panic with `[NAME, args...]`, so tests can assert on the full panic data.

// ERC-8343 / PauseModule
pub const ENFORCED_PAUSE: felt252 = 'EnforcedPause';
pub const EXPECTED_PAUSE: felt252 = 'ExpectedPause';
pub const ENFORCED_DEACTIVATION: felt252 = 'EnforcedDeactivation';
pub const ALREADY_DEACTIVATED: felt252 = 'AlreadyDeactivated';
// CMTAT_PauseModule_ContractIsDeactivated
pub const PAUSE_CONTRACT_IS_DEACTIVATED: felt252 = 'Pause_ContractIsDeactivated';

// AccessControlModule
// CMTAT_AccessControlModule_AddressZeroNotAllowed
pub const ACCESS_CONTROL_ADDRESS_ZERO: felt252 = 'AccessControl_AddressZero';

// ERC-7943 (args: account / account, amount, unfrozen)
pub const ERC7943_CANNOT_SEND: felt252 = 'ERC7943CannotSend';
pub const ERC7943_CANNOT_RECEIVE: felt252 = 'ERC7943CannotReceive';
// ERC7943InsufficientUnfrozenBalance
pub const ERC7943_INSUFFICIENT_UNFROZEN_BAL: felt252 = 'ERC7943InsufficientUnfrozenBal';

// EnforcementModule
// CMTAT_Enforcement_AccountsValueslengthMismatch
pub const ENF_ACCOUNTS_VALUES_LEN_MISMATCH: felt252 = 'Enf_AccountsValuesLenMismatch';
// CMTAT_Enforcement_EmptyAccounts
pub const ENF_EMPTY_ACCOUNTS: felt252 = 'Enf_EmptyAccounts';
// CMTAT_Enforcement_ZeroAddressNotAllowed
pub const ENF_ZERO_ADDRESS_NOT_ALLOWED: felt252 = 'Enf_ZeroAddressNotAllowed';

// ERC20EnforcementModule
// CMTAT_ERC20EnforcementModule_SelfTransferNotAllowed
pub const ERC20ENF_SELF_TRANSFER_NOT_ALLOWED: felt252 = 'ERC20Enf_SelfTransferNotAllowed';
// CMTAT_ERC20EnforcementModule_ValueEqualCurrentFrozenTokens
pub const ERC20ENF_VALUE_EQ_CURRENT_FROZEN: felt252 = 'ERC20Enf_ValueEqCurrentFrozen';
// CMTAT_ERC20EnforcementModule_ValueExceedsAvailableBalance
pub const ERC20ENF_VALUE_EXCEEDS_AVAIL_BAL: felt252 = 'ERC20Enf_ValueExceedsAvailBal';
// CMTAT_ERC20EnforcementModule_ValueExceedsFrozenBalance
pub const ERC20ENF_VALUE_EXCEEDS_FROZEN_BAL: felt252 = 'ERC20Enf_ValueExceedsFrozenBal';
// CMTAT_ERC20EnforcementModule_ZeroAddressNotAllowed
pub const ERC20ENF_ZERO_ADDRESS_NOT_ALLOWED: felt252 = 'ERC20Enf_ZeroAddressNotAllowed';

// ERC20MintModule
// CMTAT_MintModule_AccountsValueslengthMismatch
pub const MINT_ACCOUNTS_VALUES_LEN_MISMATCH: felt252 = 'Mint_AccountsValuesLenMismatch';
// CMTAT_MintModule_EmptyAccounts
pub const MINT_EMPTY_ACCOUNTS: felt252 = 'Mint_EmptyAccounts';
// CMTAT_MintModule_EmptyTos
pub const MINT_EMPTY_TOS: felt252 = 'Mint_EmptyTos';
// CMTAT_MintModule_TosValueslengthMismatch
pub const MINT_TOS_VALUES_LEN_MISMATCH: felt252 = 'Mint_TosValuesLenMismatch';

// ERC20BurnModule
// CMTAT_BurnModule_AccountsValueslengthMismatch
pub const BURN_ACCOUNTS_VALUES_LEN_MISMATCH: felt252 = 'Burn_AccountsValuesLenMismatch';
// CMTAT_BurnModule_EmptyAccounts
pub const BURN_EMPTY_ACCOUNTS: felt252 = 'Burn_EmptyAccounts';
// CMTAT_BurnEnforcement_AddressIsNotFrozen
pub const BURN_ENF_ADDRESS_IS_NOT_FROZEN: felt252 = 'BurnEnf_AddressIsNotFrozen';

// ValidationModuleRuleEngine (args: from, to, value)
// CMTAT_ValidationModule_SameValue
pub const VALIDATION_SAME_VALUE: felt252 = 'Validation_SameValue';
pub const RULE_ENGINE_INVALID_TRANSFER: felt252 = 'RuleEngine_InvalidTransfer';

// DocumentERC1643Module
pub const ERC1643_INVALID_NAME: felt252 = 'ERC1643InvalidName';
pub const ERC1643_MISSING_DOCUMENT: felt252 = 'ERC1643MissingDocument';

// SnapshotEngineModule
// CMTAT_SnapshotModule_SameValue
pub const SNAPSHOT_SAME_VALUE: felt252 = 'Snapshot_SameValue';

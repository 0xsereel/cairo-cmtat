// SPDX-License-Identifier: MPL-2.0
// CMTAT Cairo Implementation - Core Interface
// Based on CMTAT v3.0.0 Solidity reference implementation

use starknet::ContractAddress;

#[derive(Drop, Serde, Copy, PartialEq)]
pub enum CMTATTokenType {
    Standard,
    Debt,
    Allowlist,
    Light,
}

/// Core CMTAT interface combining ERC20 with compliance features
#[starknet::interface]
pub trait ICMTAT<TContractState> {
    // ERC20 Core Functions
    fn name(self: @TContractState) -> ByteArray;
    fn symbol(self: @TContractState) -> ByteArray;
    fn decimals(self: @TContractState) -> u8;
    fn total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, to: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256,
    ) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;

    // CMTAT Specific Functions
    fn version(self: @TContractState) -> ByteArray;
    fn token_type(self: @TContractState) -> CMTATTokenType;

    // Compliance Functions
    fn can_transfer(
        self: @TContractState, from: ContractAddress, to: ContractAddress, amount: u256,
    ) -> bool;
    fn can_transfer_from(
        self: @TContractState,
        spender: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        amount: u256,
    ) -> bool;

    // Supply Management (Mint/Burn)
    // Expected behavior for CMTAT v3.0.0 compliance:
    // - mint: Should check pause state, frozen addresses, rule engine restrictions, deactivation
    // - burn: Should check pause state, active balance, rule engine restrictions, deactivation
    // - batch operations: Should follow same restrictions as individual operations
    //
    // Current implementations have varying compliance levels - see inline documentation in
    // contracts
    fn mint(ref self: TContractState, to: ContractAddress, amount: u256);
    fn burn(ref self: TContractState, from: ContractAddress, amount: u256);
    fn batch_mint(ref self: TContractState, accounts: Array<ContractAddress>, amounts: Array<u256>);
    fn batch_burn(ref self: TContractState, accounts: Array<ContractAddress>, amounts: Array<u256>);
    fn batch_transfer(
        ref self: TContractState, recipients: Array<ContractAddress>, amounts: Array<u256>,
    ) -> bool;

    // Enforcement (Freeze/Unfreeze)
    fn is_frozen(self: @TContractState, account: ContractAddress) -> bool;
    fn freeze_address(ref self: TContractState, account: ContractAddress);
    fn unfreeze_address(ref self: TContractState, account: ContractAddress);
    fn batch_freeze_addresses(
        ref self: TContractState, accounts: Array<ContractAddress>, freeze_states: Array<bool>,
    );

    // Pause Functionality
    fn is_paused(self: @TContractState) -> bool;
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn is_deactivated(self: @TContractState) -> bool;
    fn deactivate_contract(ref self: TContractState);

    // Admin Functions
    fn set_name(ref self: TContractState, new_name: ByteArray);
    fn set_symbol(ref self: TContractState, new_symbol: ByteArray);

    // Forced Operations
    fn forced_transfer(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256,
    ) -> bool;
}

/// Extended CMTAT interface for advanced compliance features
#[starknet::interface]
pub trait ICMTATExtended<TContractState> {
    // Partial Token Enforcement
    fn get_frozen_tokens(self: @TContractState, account: ContractAddress) -> u256;
    fn freeze_partial_tokens(ref self: TContractState, account: ContractAddress, amount: u256);
    fn unfreeze_partial_tokens(ref self: TContractState, account: ContractAddress, amount: u256);
    fn get_active_balance(self: @TContractState, account: ContractAddress) -> u256;

    // Rule Engine Integration
    fn get_rule_engine(self: @TContractState) -> ContractAddress;
    fn set_rule_engine(ref self: TContractState, rule_engine: ContractAddress);

    // Snapshot Engine Integration
    fn get_snapshot_engine(self: @TContractState) -> ContractAddress;
    fn set_snapshot_engine(ref self: TContractState, snapshot_engine: ContractAddress);

    // Document Engine Integration
    fn get_document_engine(self: @TContractState) -> ContractAddress;
    fn set_document_engine(ref self: TContractState, document_engine: ContractAddress);

    // Extra Information
    fn get_token_id(self: @TContractState) -> ByteArray;
    fn set_token_id(ref self: TContractState, token_id: ByteArray);
    fn get_terms(self: @TContractState) -> ByteArray;
    fn set_terms(ref self: TContractState, terms: ByteArray);
    fn get_information(self: @TContractState) -> ByteArray;
    fn set_information(ref self: TContractState, information: ByteArray);
}

/// Allowlist specific interface
#[starknet::interface]
pub trait ICMTATAllowlist<TContractState> {
    fn is_allowlisted(self: @TContractState, account: ContractAddress) -> bool;
    fn add_to_allowlist(ref self: TContractState, account: ContractAddress);
    fn remove_from_allowlist(ref self: TContractState, account: ContractAddress);
    fn batch_allowlist(
        ref self: TContractState, accounts: Array<ContractAddress>, states: Array<bool>,
    );
    fn is_allowlist_enabled(self: @TContractState) -> bool;
    fn enable_allowlist(ref self: TContractState, enabled: bool);
}

/// Debt specific interface for debt instruments
#[starknet::interface]
pub trait ICMTATDebt<TContractState> {
    // Debt Information
    fn get_isin(self: @TContractState) -> ByteArray;
    fn set_isin(ref self: TContractState, isin: ByteArray);
    fn get_maturity_date(self: @TContractState) -> u64;
    fn set_maturity_date(ref self: TContractState, maturity_date: u64);
    fn get_interest_rate(self: @TContractState) -> u256;
    fn set_interest_rate(ref self: TContractState, interest_rate: u256);
    fn get_par_value(self: @TContractState) -> u256;
    fn set_par_value(ref self: TContractState, par_value: u256);

    // Credit Events
    fn has_credit_event(self: @TContractState) -> bool;
    fn get_credit_event_type(self: @TContractState) -> ByteArray;
    fn set_credit_event(ref self: TContractState, event_type: ByteArray, occurred: bool);
}

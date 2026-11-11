// SPDX-License-Identifier: MPL-2.0
// RuleEngine interfaces. Production RuleEngines live outside this repository, as
// in CMTA's own repositories; `src/mocks` has a recorder for tests.

use starknet::ContractAddress;

/// Implemented by the RuleEngine.
#[starknet::interface]
pub trait IRuleEngine<TState> {
    /// ERC-3643 compliance hook, called for transfers without a spender.
    fn transferred(ref self: TState, from: ContractAddress, to: ContractAddress, value: u256);
    /// `transferred(spender, from, to, value)` in CMTAT: called when a spender or
    /// operator is involved (transfer_from, mint, burn, batch transfer).
    fn transferred_with_spender(
        ref self: TState,
        spender: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        value: u256,
    );
    fn can_transfer(self: @TState, from: ContractAddress, to: ContractAddress, value: u256) -> bool;
    fn can_transfer_from(
        self: @TState,
        spender: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        value: u256,
    ) -> bool;
}

/// Implemented by RuleEngines that report ERC-1404 codes (7-12).
#[starknet::interface]
pub trait IRuleEngineERC1404<TState> {
    fn detect_transfer_restriction(
        self: @TState, from: ContractAddress, to: ContractAddress, value: u256,
    ) -> u8;
    fn detect_transfer_restriction_from(
        self: @TState,
        spender: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        value: u256,
    ) -> u8;
    fn message_for_transfer_restriction(self: @TState, restriction_code: u8) -> ByteArray;
}

/// Implemented by the token.
#[starknet::interface]
pub trait IValidationRuleEngine<TState> {
    fn rule_engine(self: @TState) -> ContractAddress;
    /// Requires DEFAULT_ADMIN_ROLE. The zero address removes the engine.
    fn set_rule_engine(ref self: TState, rule_engine: ContractAddress);
}

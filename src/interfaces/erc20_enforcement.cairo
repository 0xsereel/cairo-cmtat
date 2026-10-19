// SPDX-License-Identifier: MPL-2.0
// Partial token freeze and forced transfer: ERC-3643, ERC-7943 and ERC-7551.
// `get_frozen_tokens` appears in all three standards; it is declared once, in
// IERC7943FungibleEnforcement, so the traits can be embedded side by side.

use starknet::ContractAddress;

/// SNIP-5 id of ERC-7943 fungible (CMTAT's `0x3edbb4c4`): XOR of the extended
/// selectors of
/// `get_frozen_tokens(ContractAddress)->(u128,u128)`,
/// `set_frozen_tokens(ContractAddress,(u128,u128))->E((),())`,
/// `forced_transfer(ContractAddress,ContractAddress,(u128,u128))->E((),())`,
/// `can_send(ContractAddress)->E((),())`,
/// `can_receive(ContractAddress)->E((),())` and
/// `can_transfer(ContractAddress,ContractAddress,(u128,u128))->E((),())`.
pub const IERC7943_ID: felt252 = 0x14e4423410d8cc56f38ff233c6d8d427700f0c7929a1ef8c0c9d117955b3ec1;

#[starknet::interface]
pub trait IERC3643ERC20Enforcement<TState> {
    fn freeze_partial_tokens(ref self: TState, account: ContractAddress, value: u256);
    fn unfreeze_partial_tokens(ref self: TState, account: ContractAddress, value: u256);
}

#[starknet::interface]
pub trait IERC7943FungibleEnforcement<TState> {
    fn get_frozen_tokens(self: @TState, account: ContractAddress) -> u256;
    fn set_frozen_tokens(ref self: TState, account: ContractAddress, value: u256) -> bool;
    /// Moves `value` from `from` to `to` regardless of freeze status, unfreezing
    /// tokens as needed. `to == 0` burns.
    fn forced_transfer(
        ref self: TState, from: ContractAddress, to: ContractAddress, value: u256,
    ) -> bool;
}

#[starknet::interface]
pub trait IERC7551ERC20Enforcement<TState> {
    fn get_active_balance_of(self: @TState, account: ContractAddress) -> u256;
    fn freeze_partial_tokens_with_data(
        ref self: TState, account: ContractAddress, value: u256, data: Span<felt252>,
    );
    fn unfreeze_partial_tokens_with_data(
        ref self: TState, account: ContractAddress, value: u256, data: Span<felt252>,
    );
    fn forced_transfer_with_data(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        value: u256,
        data: Span<felt252>,
    ) -> bool;
}

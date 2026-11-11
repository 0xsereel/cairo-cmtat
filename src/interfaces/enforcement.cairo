// SPDX-License-Identifier: MPL-2.0
// ERC-3643 address freeze, plus CMTAT's data overload.

use starknet::ContractAddress;

#[starknet::interface]
pub trait IERC3643Enforcement<TState> {
    fn set_address_frozen(ref self: TState, account: ContractAddress, freeze: bool);
    fn batch_set_address_frozen(
        ref self: TState, accounts: Span<ContractAddress>, freezes: Span<bool>,
    );
    fn is_frozen(self: @TState, account: ContractAddress) -> bool;
}

#[starknet::interface]
pub trait ICMTATEnforcement<TState> {
    /// `setAddressFrozen(account, freeze, data)` in CMTAT.
    fn set_address_frozen_with_data(
        ref self: TState, account: ContractAddress, freeze: bool, data: Span<felt252>,
    );
}

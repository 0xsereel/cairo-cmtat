// SPDX-License-Identifier: MPL-2.0
// CMTAT AllowlistModule.

use starknet::ContractAddress;

#[starknet::interface]
pub trait IAllowlistModule<TState> {
    fn set_address_allowlist(ref self: TState, account: ContractAddress, status: bool);
    /// `setAddressAllowlist(account, status, data)` in CMTAT.
    fn set_address_allowlist_with_data(
        ref self: TState, account: ContractAddress, status: bool, data: Span<felt252>,
    );
    fn batch_set_address_allowlist(
        ref self: TState, accounts: Span<ContractAddress>, statuses: Span<bool>,
    );
    fn enable_allowlist(ref self: TState, status: bool);
    fn is_allowlist_enabled(self: @TState) -> bool;
    fn is_allowlisted(self: @TState, account: ContractAddress) -> bool;
}

// SPDX-License-Identifier: MPL-2.0
// ERC-3643 mint and batch transfer, plus the ERC-5679 / ERC-7551 data overload.

use starknet::ContractAddress;

/// SNIP-5 id of ERC-5679 (mint and burn with data; CMTAT's `0xd0017968`): XOR
/// of the extended selectors of
/// `mint_with_data(ContractAddress,(u128,u128),(@Array<felt252>))` and
/// `burn_with_data(ContractAddress,(u128,u128),(@Array<felt252>))`.
pub const IERC5679_ID: felt252 = 0x33c89e5cd6ccac5fc9f984d94defdfc99b2cadda15b0422f41b9b848de233c8;

#[starknet::interface]
pub trait IERC3643Mint<TState> {
    fn mint(ref self: TState, account: ContractAddress, value: u256);
    fn batch_mint(ref self: TState, accounts: Span<ContractAddress>, values: Span<u256>);
}

#[starknet::interface]
pub trait IERC3643BatchTransfer<TState> {
    /// Transfers the caller's (minter's) tokens to each of `tos`.
    fn batch_transfer(ref self: TState, tos: Span<ContractAddress>, values: Span<u256>) -> bool;
}

#[starknet::interface]
pub trait IERC5679Mint<TState> {
    /// `mint(account, value, data)` in CMTAT.
    fn mint_with_data(ref self: TState, account: ContractAddress, value: u256, data: Span<felt252>);
}

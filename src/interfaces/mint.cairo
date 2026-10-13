// SPDX-License-Identifier: MPL-2.0
// ERC-3643 mint and batch transfer, plus the ERC-5679 / ERC-7551 data overload.

use starknet::ContractAddress;

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

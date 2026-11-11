// SPDX-License-Identifier: MPL-2.0
// Burn entry points: ERC-3643, ERC-5679 / ERC-7551 data overloads, burn-from and
// self-burn (CMTAT ERC20CrossChainModule), burn-and-mint and Light's forced burn.

use starknet::ContractAddress;

#[starknet::interface]
pub trait IERC3643Burn<TState> {
    fn burn(ref self: TState, account: ContractAddress, value: u256);
    fn batch_burn(ref self: TState, accounts: Span<ContractAddress>, values: Span<u256>);
}

#[starknet::interface]
pub trait IERC5679Burn<TState> {
    /// `burn(account, value, data)` in CMTAT.
    fn burn_with_data(ref self: TState, account: ContractAddress, value: u256, data: Span<felt252>);
}

#[starknet::interface]
pub trait IBurnBatchERC20<TState> {
    /// `batchBurn(accounts, values, data)` in CMTAT.
    fn batch_burn_with_data(
        ref self: TState, accounts: Span<ContractAddress>, values: Span<u256>, data: Span<felt252>,
    );
}

#[starknet::interface]
pub trait IBurnFromERC20<TState> {
    /// Burns `value` of `account`'s tokens, spending the caller's allowance.
    fn burn_from(ref self: TState, account: ContractAddress, value: u256);
    /// `burn(value)` in CMTAT: the caller burns its own tokens. Renamed because
    /// Cairo has no overloading and `burn(account, value)` is the ERC-3643 entry point.
    fn burn_self(ref self: TState, value: u256);
}

#[starknet::interface]
pub trait IBurnMintERC20<TState> {
    fn burn_and_mint(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        amount_to_burn: u256,
        amount_to_mint: u256,
        data: Span<felt252>,
    );
}

#[starknet::interface]
pub trait IForcedBurnERC20<TState> {
    /// Light only: burns from a frozen address without compliance checks.
    fn forced_burn(ref self: TState, account: ContractAddress, value: u256, data: Span<felt252>);
}

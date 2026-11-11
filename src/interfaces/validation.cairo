// SPDX-License-Identifier: MPL-2.0
// Compliance reads: ERC-7943 send/receive checks, ERC-3643 `can_transfer` and the
// ERC-7551 spender variant. None of them check balances or access rights, except
// that non-Light presets include the active-balance check, as CMTAT does.

use starknet::ContractAddress;

#[starknet::interface]
pub trait IERC7943FungibleSendReceiveCheck<TState> {
    fn can_send(self: @TState, account: ContractAddress) -> bool;
    fn can_receive(self: @TState, account: ContractAddress) -> bool;
}

#[starknet::interface]
pub trait IERC3643ComplianceRead<TState> {
    fn can_transfer(self: @TState, from: ContractAddress, to: ContractAddress, value: u256) -> bool;
}

#[starknet::interface]
pub trait IERC7551Compliance<TState> {
    fn can_transfer_from(
        self: @TState,
        spender: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        value: u256,
    ) -> bool;
}

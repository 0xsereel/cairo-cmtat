// SPDX-License-Identifier: MPL-2.0
// ERC-1404 transfer restrictions and CMTAT's spender extension.
//
// Codes match IERC1404Extend.REJECTED_CODE_BASE. Codes 7-12 are reserved for
// RuleEngines.

use starknet::ContractAddress;

pub const TRANSFER_OK: u8 = 0;
pub const TRANSFER_REJECTED_DEACTIVATED: u8 = 1;
pub const TRANSFER_REJECTED_PAUSED: u8 = 2;
pub const TRANSFER_REJECTED_FROM_FROZEN: u8 = 3;
pub const TRANSFER_REJECTED_TO_FROZEN: u8 = 4;
pub const TRANSFER_REJECTED_SPENDER_FROZEN: u8 = 5;
pub const TRANSFER_REJECTED_FROM_INSUFFICIENT_ACTIVE_BALANCE: u8 = 6;

#[starknet::interface]
pub trait IERC1404<TState> {
    fn detect_transfer_restriction(
        self: @TState, from: ContractAddress, to: ContractAddress, value: u256,
    ) -> u8;
    fn message_for_transfer_restriction(self: @TState, restriction_code: u8) -> ByteArray;
}

#[starknet::interface]
pub trait IERC1404Extend<TState> {
    fn detect_transfer_restriction_from(
        self: @TState,
        spender: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        value: u256,
    ) -> u8;
}

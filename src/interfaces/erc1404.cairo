// SPDX-License-Identifier: MPL-2.0
// ERC-1404 transfer restrictions and CMTAT's spender extension.
//
// Codes match IERC1404Extend.REJECTED_CODE_BASE. Codes 7-12 are reserved for
// RuleEngines.

use starknet::ContractAddress;

/// SNIP-5 id of ERC-1404: XOR of the extended selectors of
/// `detect_transfer_restriction(ContractAddress,ContractAddress,(u128,u128))->u8`
/// and `message_for_transfer_restriction(u8)->(Array<bytes31>,felt252,u32)`.
pub const IERC1404_ID: felt252 = 0x3a3c667090ad0aa8f47799a4995ee74f3ca62bdaf5d64d75cd41596255f182a;

/// SNIP-5 id of IERC1404Extend. As in CMTAT (`0x78a8de7d`), it includes the
/// ERC-1404 functions: `IERC1404_ID` XOR the extended selector of
/// `detect_transfer_restriction_from(ContractAddress,ContractAddress,ContractAddress,(u128,u128))->u8`.
pub const IERC1404_EXTEND_ID: felt252 =
    0xff711fc962f6084c61e8a81115059929cf17dc2fe08b83e577453465d0e7fe;

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

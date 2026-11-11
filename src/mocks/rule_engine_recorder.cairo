// SPDX-License-Identifier: MPL-2.0
// Test RuleEngine that records every `transferred` call. It can be configured to
// reject transfers, answer `can_transfer` with false, report an ERC-1404 code,
// or reenter the token during `transferred`. Its read functions can also depend
// on their arguments (a blocked address, a maximum value), so tests can check
// what the token passes to the engine on the read path.

use starknet::ContractAddress;

/// ERC-1404 code the reads return for a blocked spender, from or to.
pub const BLOCKED_CODE: u8 = 10;
/// ERC-1404 code the reads return for a value above the maximum.
pub const VALUE_CODE: u8 = 11;

#[derive(Copy, Drop, Debug, PartialEq, Serde, starknet::Store)]
pub struct RecordedCall {
    /// True for `transferred_with_spender`, false for the ERC-3643 `transferred`.
    pub with_spender: bool,
    pub spender: ContractAddress,
    pub from: ContractAddress,
    pub to: ContractAddress,
    pub value: u256,
}

#[starknet::interface]
pub trait IRuleEngineRecorder<TState> {
    fn set_reject(ref self: TState, reject: bool);
    fn set_can_transfer(ref self: TState, allowed: bool);
    fn set_code(ref self: TState, code: u8);
    /// When set, the next `transferred` calls `transfer(to, value)` on `token` from the
    /// engine, once.
    fn set_reenter(ref self: TState, token: ContractAddress);
    /// Reads deny (and report BLOCKED_CODE) when `account` is the spender, from
    /// or to. `account` may be zero, to target mint- or burn-shaped reads.
    fn set_blocked(ref self: TState, account: ContractAddress);
    /// Reads deny (and report VALUE_CODE) when the value exceeds `max_value`.
    fn set_max_value(ref self: TState, max_value: u256);
    fn call_count(self: @TState) -> u64;
    fn call_at(self: @TState, index: u64) -> RecordedCall;
}

#[starknet::contract]
pub mod RuleEngineRecorder {
    use core::num::traits::Zero;
    use openzeppelin::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::ContractAddress;
    use starknet::storage::{
        MutableVecTrait, StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
    };
    use crate::errors;
    use crate::interfaces::rule_engine::{IRuleEngine, IRuleEngineERC1404};
    use super::RecordedCall;

    #[storage]
    struct Storage {
        calls: Vec<RecordedCall>,
        reject: bool,
        deny_can_transfer: bool,
        code: u8,
        reenter_token: ContractAddress,
        blocking: bool,
        blocked: ContractAddress,
        limiting: bool,
        max_value: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[abi(embed_v0)]
    impl RecorderImpl of super::IRuleEngineRecorder<ContractState> {
        fn set_reject(ref self: ContractState, reject: bool) {
            self.reject.write(reject);
        }

        fn set_can_transfer(ref self: ContractState, allowed: bool) {
            self.deny_can_transfer.write(!allowed);
        }

        fn set_code(ref self: ContractState, code: u8) {
            self.code.write(code);
        }

        fn set_reenter(ref self: ContractState, token: ContractAddress) {
            self.reenter_token.write(token);
        }

        fn set_blocked(ref self: ContractState, account: ContractAddress) {
            self.blocking.write(true);
            self.blocked.write(account);
        }

        fn set_max_value(ref self: ContractState, max_value: u256) {
            self.limiting.write(true);
            self.max_value.write(max_value);
        }

        fn call_count(self: @ContractState) -> u64 {
            self.calls.len()
        }

        fn call_at(self: @ContractState, index: u64) -> RecordedCall {
            self.calls.at(index).read()
        }
    }

    #[abi(embed_v0)]
    impl RuleEngineImpl of IRuleEngine<ContractState> {
        fn transferred(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, value: u256,
        ) {
            self.record(false, Zero::zero(), from, to, value);
        }

        fn transferred_with_spender(
            ref self: ContractState,
            spender: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
        ) {
            self.record(true, spender, from, to, value);
        }

        fn can_transfer(
            self: @ContractState, from: ContractAddress, to: ContractAddress, value: u256,
        ) -> bool {
            !self.deny_can_transfer.read() && self.read_code(Zero::zero(), from, to, value) == 0
        }

        fn can_transfer_from(
            self: @ContractState,
            spender: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
        ) -> bool {
            !self.deny_can_transfer.read() && self.read_code(spender, from, to, value) == 0
        }
    }

    #[abi(embed_v0)]
    impl RuleEngineERC1404Impl of IRuleEngineERC1404<ContractState> {
        fn detect_transfer_restriction(
            self: @ContractState, from: ContractAddress, to: ContractAddress, value: u256,
        ) -> u8 {
            let code = self.read_code(Zero::zero(), from, to, value);
            if code != 0 {
                code
            } else {
                self.code.read()
            }
        }

        fn detect_transfer_restriction_from(
            self: @ContractState,
            spender: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
        ) -> u8 {
            let code = self.read_code(spender, from, to, value);
            if code != 0 {
                code
            } else {
                self.code.read()
            }
        }

        fn message_for_transfer_restriction(
            self: @ContractState, restriction_code: u8,
        ) -> ByteArray {
            "RecorderRestriction"
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// BLOCKED_CODE or VALUE_CODE when the arguments trip a configured rule,
        /// else 0. A zero spender (non-`_from` reads) never matches a block.
        fn read_code(
            self: @ContractState,
            spender: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
        ) -> u8 {
            if self.blocking.read() {
                let blocked = self.blocked.read();
                let spender_blocked = spender.is_non_zero() && spender == blocked;
                if spender_blocked || from == blocked || to == blocked {
                    return super::BLOCKED_CODE;
                }
            }
            if self.limiting.read() && value > self.max_value.read() {
                return super::VALUE_CODE;
            }
            0
        }

        fn record(
            ref self: ContractState,
            with_spender: bool,
            spender: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
        ) {
            if self.reject.read() {
                let mut data = array![errors::RULE_ENGINE_INVALID_TRANSFER];
                from.serialize(ref data);
                to.serialize(ref data);
                value.serialize(ref data);
                panic(data);
            }
            self.calls.push(RecordedCall { with_spender, spender, from, to, value });
            // Reenter once, so an unguarded token is caught by assertions rather
            // than by unbounded recursion.
            let token = self.reenter_token.read();
            if token.is_non_zero() {
                self.reenter_token.write(Zero::zero());
                IERC20Dispatcher { contract_address: token }.transfer(to, value);
            }
        }
    }
}

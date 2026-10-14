// SPDX-License-Identifier: MPL-2.0
// Test SnapshotEngine that records every `operate_on_transfer` call.

use starknet::ContractAddress;

#[derive(Copy, Drop, Debug, PartialEq, Serde, starknet::Store)]
pub struct SnapshotCall {
    pub from: ContractAddress,
    pub to: ContractAddress,
    pub balance_from: u256,
    pub balance_to: u256,
    pub total_supply: u256,
}

#[starknet::interface]
pub trait ISnapshotEngineRecorder<TState> {
    fn call_count(self: @TState) -> u64;
    fn call_at(self: @TState, index: u64) -> SnapshotCall;
}

#[starknet::contract]
pub mod SnapshotEngineRecorder {
    use starknet::ContractAddress;
    use starknet::storage::{MutableVecTrait, StoragePointerReadAccess, Vec, VecTrait};
    use crate::interfaces::snapshot::ISnapshotEngine;
    use super::SnapshotCall;

    #[storage]
    struct Storage {
        calls: Vec<SnapshotCall>,
    }

    #[abi(embed_v0)]
    impl RecorderImpl of super::ISnapshotEngineRecorder<ContractState> {
        fn call_count(self: @ContractState) -> u64 {
            self.calls.len()
        }

        fn call_at(self: @ContractState, index: u64) -> SnapshotCall {
            self.calls.at(index).read()
        }
    }

    #[abi(embed_v0)]
    impl SnapshotEngineImpl of ISnapshotEngine<ContractState> {
        fn operate_on_transfer(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            balance_from: u256,
            balance_to: u256,
            total_supply: u256,
        ) {
            self.calls.push(SnapshotCall { from, to, balance_from, balance_to, total_supply });
        }
    }
}

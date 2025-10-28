// SPDX-License-Identifier: MPL-2.0
// Simple Snapshot Demo Contract

use starknet::ContractAddress;

#[starknet::interface]
trait ISnapshotDemo<TContractState> {
    fn trigger_snapshot(ref self: TContractState, snapshot_id: u64);
    fn get_demo_balance(self: @TContractState, account: ContractAddress) -> u256;
    fn set_demo_balance(ref self: TContractState, account: ContractAddress, balance: u256);
}

#[starknet::contract]
mod SnapshotDemo {
    use super::ISnapshotDemo;
    use starknet::{ContractAddress, get_caller_address};
    use cairo_cmtat::engines::snapshot_engine::{ISnapshotEngineDispatcher, ISnapshotEngineDispatcherTrait, ISnapshotRecordingDispatcher, ISnapshotRecordingDispatcherTrait};

    #[storage]
    struct Storage {
        snapshot_engine: ContractAddress,
        demo_balances: LegacyMap<ContractAddress, u256>,
        total_supply: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, snapshot_engine: ContractAddress) {
        self.snapshot_engine.write(snapshot_engine);
        self.total_supply.write(1000000000000000000000000_u256); // 1M tokens
    }

    #[abi(embed_v0)]
    impl SnapshotDemoImpl of ISnapshotDemo<ContractState> {
        fn trigger_snapshot(ref self: ContractState, snapshot_id: u64) {
            let engine_addr = self.snapshot_engine.read();
            let recording = ISnapshotRecordingDispatcher { contract_address: engine_addr };
            
            // Record the snapshot with current total supply
            let total = self.total_supply.read();
            recording.record_snapshot(snapshot_id, total);
        }

        fn get_demo_balance(self: @ContractState, account: ContractAddress) -> u256 {
            self.demo_balances.read(account)
        }

        fn set_demo_balance(ref self: ContractState, account: ContractAddress, balance: u256) {
            self.demo_balances.write(account, balance);
        }
    }
}
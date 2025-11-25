// SPDX-License-Identifier: MPL-2.0
// Simplified Snapshot Engine for CMTAT Cairo

use starknet::ContractAddress;


/// Snapshot data structure
#[derive(Drop, Serde, starknet::Store)]
pub struct Snapshot {
    pub id: u64,
    pub timestamp: u64,
    pub total_supply: u256,
}

/// Snapshot Engine Interface - Records token state at specific points in time
#[starknet::interface]
pub trait ISnapshotEngine<TContractState> {
    /// Create a new snapshot
    fn schedule_snapshot(ref self: TContractState, timestamp: u64) -> u64;
    
    /// Set the authorized token contract
    fn set_token_contract(ref self: TContractState, new_token_contract: ContractAddress);
    
    /// Get the authorized token contract
    fn get_token_contract(self: @TContractState) -> ContractAddress;
    
    /// Get snapshot by ID
    fn get_snapshot(self: @TContractState, snapshot_id: u64) -> Snapshot;
    
    /// Get account balance at snapshot
    fn balance_of_at(self: @TContractState, account: ContractAddress, snapshot_id: u64) -> u256;
    
    /// Get total supply at snapshot  
    fn total_supply_at(self: @TContractState, snapshot_id: u64) -> u256;
    
    /// Get latest snapshot ID
    fn get_next_snapshot_id(self: @TContractState) -> u64;
    
    /// Batch query balances at snapshot
    fn batch_balance_of_at(
        self: @TContractState,
        accounts: Array<ContractAddress>,
        snapshot_id: u64
    ) -> (Array<u256>, u256);
}

/// Simple Snapshot Engine Implementation
#[starknet::contract]
mod SimpleSnapshotEngine {
    use super::{ISnapshotEngine, Snapshot};
    use openzeppelin::access::ownable::OwnableComponent;
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        token_contract: ContractAddress,
        // Snapshot ID counter
        next_snapshot_id: u64,
        // snapshot_id => Snapshot data
        snapshots: Map<u64, Snapshot>,
        // snapshot_id => account => balance
        balances_at_snapshot: Map<(u64, ContractAddress), u256>,
        // Scheduled snapshots: timestamp => snapshot_id
        scheduled_snapshots: Map<u64, u64>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        SnapshotScheduled: SnapshotScheduled,
        SnapshotCreated: SnapshotCreated,
        BalanceRecorded: BalanceRecorded,
    }

    #[derive(Drop, starknet::Event)]
    struct SnapshotScheduled {
        #[key]
        pub snapshot_id: u64,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct SnapshotCreated {
        #[key]
        pub snapshot_id: u64,
        pub timestamp: u64,
        pub total_supply: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct BalanceRecorded {
        #[key]
        pub snapshot_id: u64,
        #[key]
        pub account: ContractAddress,
        pub balance: u256,
    }

    mod Errors {
        pub const INVALID_SNAPSHOT: felt252 = 'Snapshot: invalid ID';
        pub const SNAPSHOT_NOT_READY: felt252 = 'Snapshot: not ready';
        pub const UNAUTHORIZED: felt252 = 'Snapshot: unauthorized';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        token_contract: ContractAddress
    ) {
        self.ownable.initializer(owner);
        self.token_contract.write(token_contract);
        self.next_snapshot_id.write(1);
    }

    #[abi(embed_v0)]
    impl SnapshotEngineImpl of ISnapshotEngine<ContractState> {
        fn schedule_snapshot(ref self: ContractState, timestamp: u64) -> u64 {
            self.ownable.assert_only_owner();
            
            let snapshot_id = self.next_snapshot_id.read();
            self.next_snapshot_id.write(snapshot_id + 1);
            
            self.scheduled_snapshots.write(timestamp, snapshot_id);
            
            self.emit(SnapshotScheduled { snapshot_id, timestamp });
            
            snapshot_id
        }

        fn set_token_contract(ref self: ContractState, new_token_contract: ContractAddress) {
            self.ownable.assert_only_owner();
            self.token_contract.write(new_token_contract);
        }

        fn get_token_contract(self: @ContractState) -> ContractAddress {
            self.token_contract.read()
        }

        fn get_snapshot(self: @ContractState, snapshot_id: u64) -> Snapshot {
            self.snapshots.read(snapshot_id)
        }

        fn balance_of_at(
            self: @ContractState,
            account: ContractAddress,
            snapshot_id: u64
        ) -> u256 {
            // Verify snapshot exists
            let snapshot = self.snapshots.read(snapshot_id);
            assert(snapshot.id == snapshot_id, Errors::INVALID_SNAPSHOT);
            
            self.balances_at_snapshot.read((snapshot_id, account))
        }

        fn total_supply_at(self: @ContractState, snapshot_id: u64) -> u256 {
            let snapshot = self.snapshots.read(snapshot_id);
            assert(snapshot.id == snapshot_id, Errors::INVALID_SNAPSHOT);
            
            snapshot.total_supply
        }

        fn get_next_snapshot_id(self: @ContractState) -> u64 {
            self.next_snapshot_id.read()
        }

        fn batch_balance_of_at(
            self: @ContractState,
            accounts: Array<ContractAddress>,
            snapshot_id: u64
        ) -> (Array<u256>, u256) {
            let snapshot = self.snapshots.read(snapshot_id);
            assert(snapshot.id == snapshot_id, Errors::INVALID_SNAPSHOT);
            
            let mut balances: Array<u256> = ArrayTrait::new();
            let mut i = 0;
            
            loop {
                if i >= accounts.len() {
                    break;
                }
                let account = *accounts.at(i);
                let balance = self.balances_at_snapshot.read((snapshot_id, account));
                balances.append(balance);
                i += 1;
            };
            
            (balances, snapshot.total_supply)
        }
    }

    #[abi(embed_v0)]
    impl SnapshotRecording of super::ISnapshotRecording<ContractState> {
        fn record_snapshot(
            ref self: ContractState,
            snapshot_id: u64,
            total_supply: u256
        ) {
            // Only token contract can record snapshots
            assert(get_caller_address() == self.token_contract.read(), Errors::UNAUTHORIZED);
            
            let timestamp = get_block_timestamp();
            
            let snapshot = Snapshot {
                id: snapshot_id,
                timestamp,
                total_supply
            };
            
            self.snapshots.write(snapshot_id, snapshot);
            
            self.emit(SnapshotCreated { snapshot_id, timestamp, total_supply });
        }

        fn record_balance(
            ref self: ContractState,
            snapshot_id: u64,
            account: ContractAddress,
            balance: u256
        ) {
            // Only token contract can record balances
            assert(get_caller_address() == self.token_contract.read(), Errors::UNAUTHORIZED);
            
            self.balances_at_snapshot.write((snapshot_id, account), balance);
            
            self.emit(BalanceRecorded { snapshot_id, account, balance });
        }

        fn batch_record_balances(
            ref self: ContractState,
            snapshot_id: u64,
            accounts: Array<ContractAddress>,
            balances: Array<u256>
        ) {
            assert(get_caller_address() == self.token_contract.read(), Errors::UNAUTHORIZED);
            assert(accounts.len() == balances.len(), 'Length mismatch');
            
            let mut i = 0;
            loop {
                if i >= accounts.len() {
                    break;
                }
                let account = *accounts.at(i);
                let balance = *balances.at(i);
                
                self.balances_at_snapshot.write((snapshot_id, account), balance);
                self.emit(BalanceRecorded { snapshot_id, account, balance });
                
                i += 1;
            }
        }
    }
}

#[starknet::interface]
pub trait ISnapshotRecording<TContractState> {
    fn record_snapshot(ref self: TContractState, snapshot_id: u64, total_supply: u256);
    fn record_balance(
        ref self: TContractState,
        snapshot_id: u64,
        account: ContractAddress,
        balance: u256
    );
    fn batch_record_balances(
        ref self: TContractState,
        snapshot_id: u64,
        accounts: Array<ContractAddress>,
        balances: Array<u256>
    );
}

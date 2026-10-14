// SPDX-License-Identifier: MPL-2.0
// CMTAT SnapshotEngineModule + CMTATBaseSnapshot: an optional SnapshotEngine,
// set under SNAPSHOOTER_ROLE, notified after every balance change (transfer,
// mint, burn, forced transfer) through `SnapshotERC20HooksImpl`.
//
// CMTAT passes the balances and total supply from before the update. The
// OpenZeppelin ERC-20 `after_update` hook sees post-update state, so the
// pre-update values are derived from the amount.

#[starknet::component]
pub mod SnapshotComponent {
    use core::num::traits::Zero;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use crate::components::access::CMTATAccessControlComponent;
    use crate::components::access::CMTATAccessControlComponent::InternalImpl as AccessInternalImpl;
    use crate::errors;
    use crate::interfaces::snapshot::{
        ISnapshotEngineDispatcher, ISnapshotEngineDispatcherTrait, ISnapshotEngineModule,
    };
    use crate::roles::SNAPSHOOTER_ROLE;

    #[storage]
    pub struct Storage {
        pub SnapshotEngineModule_snapshot_engine: ContractAddress,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        SnapshotEngine: SnapshotEngineSet,
    }

    /// CMTAT `SnapshotEngine(ISnapshotEngine indexed newSnapshotEngine)`.
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct SnapshotEngineSet {
        #[key]
        pub new_snapshot_engine: ContractAddress,
    }

    #[embeddable_as(SnapshotEngineModuleImpl)]
    impl SnapshotEngineModule<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        impl Access: CMTATAccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of ISnapshotEngineModule<ComponentState<TContractState>> {
        fn snapshot_engine(self: @ComponentState<TContractState>) -> ContractAddress {
            self.SnapshotEngineModule_snapshot_engine.read()
        }

        fn set_snapshot_engine(
            ref self: ComponentState<TContractState>, snapshot_engine: ContractAddress,
        ) {
            get_dep_component!(@self, Access).assert_only_role(SNAPSHOOTER_ROLE);
            assert(
                snapshot_engine != self.SnapshotEngineModule_snapshot_engine.read(),
                errors::SNAPSHOT_SAME_VALUE,
            );
            self._set_snapshot_engine(snapshot_engine);
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Sets the engine at deployment; the zero address leaves it unset.
        fn initializer(ref self: ComponentState<TContractState>, snapshot_engine: ContractAddress) {
            if snapshot_engine.is_non_zero() {
                self._set_snapshot_engine(snapshot_engine);
            }
        }

        fn _set_snapshot_engine(
            ref self: ComponentState<TContractState>, snapshot_engine: ContractAddress,
        ) {
            self.SnapshotEngineModule_snapshot_engine.write(snapshot_engine);
            self.emit(SnapshotEngineSet { new_snapshot_engine: snapshot_engine });
        }

        /// Notifies the engine of a completed update. `balance_from_after`,
        /// `balance_to_after` and `total_supply_after` are post-update values; the
        /// engine receives the pre-update ones.
        fn operate_on_transfer(
            self: @ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256,
            balance_from_after: u256,
            balance_to_after: u256,
            total_supply_after: u256,
        ) {
            let engine = self.SnapshotEngineModule_snapshot_engine.read();
            if engine.is_zero() {
                return;
            }
            let (balance_from, balance_to) = if from == to {
                (balance_from_after, balance_to_after)
            } else {
                let balance_from = if from.is_zero() {
                    0
                } else {
                    balance_from_after + amount
                };
                let balance_to = if to.is_zero() {
                    0
                } else {
                    balance_to_after - amount
                };
                (balance_from, balance_to)
            };
            let total_supply = if from.is_zero() && to.is_non_zero() {
                total_supply_after - amount
            } else if to.is_zero() && from.is_non_zero() {
                total_supply_after + amount
            } else {
                total_supply_after
            };
            ISnapshotEngineDispatcher { contract_address: engine }
                .operate_on_transfer(from, to, balance_from, balance_to, total_supply);
        }
    }
}

// SPDX-License-Identifier: MPL-2.0
// Class upgrades (`replace_class`) under DEFAULT_ADMIN_ROLE, over OpenZeppelin's
// UpgradeableComponent. Storage persists across upgrades, so every component
// uses module-prefixed storage names.
//
// Migration pattern (after Solidity `Initializable.reinitializer`): presets
// start at INITIAL_VERSION. A new class whose storage needs migrating exposes
// its own `migrate` entry point that calls `reinitializer(n)` and then moves the
// data. Each version runs once and versions only increase, so `migrate` cannot
// be replayed. `upgrade` and `migrate` are separate calls; send them in one
// account multicall so no transaction sees unmigrated storage under the new
// class.

pub const INITIAL_VERSION: u64 = 1;

#[starknet::component]
pub mod UpgradeComponent {
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::interfaces::upgrades::IUpgradeable;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::UpgradeableComponent::InternalImpl as UpgradeableInternalImpl;
    use starknet::ClassHash;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use crate::components::access::CMTATAccessControlComponent;
    use crate::components::access::CMTATAccessControlComponent::InternalImpl as AccessInternalImpl;
    use crate::errors::INVALID_INITIALIZATION;
    use crate::interfaces::upgrade::IUpgradeVersion;
    use crate::roles::DEFAULT_ADMIN_ROLE;

    #[storage]
    pub struct Storage {
        pub UpgradeModule_initialized_version: u64,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        Initialized: Initialized,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct Initialized {
        pub version: u64,
    }

    #[embeddable_as(UpgradeableImpl)]
    impl Upgradeable<
        TContractState,
        +HasComponent<TContractState>,
        impl OZUpgradeable: UpgradeableComponent::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        impl Access: CMTATAccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IUpgradeable<ComponentState<TContractState>> {
        fn upgrade(ref self: ComponentState<TContractState>, new_class_hash: ClassHash) {
            get_dep_component!(@self, Access).assert_only_role(DEFAULT_ADMIN_ROLE);
            get_dep_component_mut!(ref self, OZUpgradeable).upgrade(new_class_hash);
        }
    }

    #[embeddable_as(UpgradeVersionImpl)]
    impl UpgradeVersion<
        TContractState, +HasComponent<TContractState>,
    > of IUpgradeVersion<ComponentState<TContractState>> {
        fn initialized_version(self: @ComponentState<TContractState>) -> u64 {
            self.UpgradeModule_initialized_version.read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        impl Access: CMTATAccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Constructor only: records the storage version of a fresh deployment.
        fn initializer(ref self: ComponentState<TContractState>, version: u64) {
            self._set_version(version);
        }

        /// For a new class's `migrate`: requires DEFAULT_ADMIN_ROLE and a version
        /// above the current one.
        fn reinitializer(ref self: ComponentState<TContractState>, version: u64) {
            get_dep_component!(@self, Access).assert_only_role(DEFAULT_ADMIN_ROLE);
            self._set_version(version);
        }

        fn _set_version(ref self: ComponentState<TContractState>, version: u64) {
            assert(version > self.UpgradeModule_initialized_version.read(), INVALID_INITIALIZATION);
            self.UpgradeModule_initialized_version.write(version);
            self.emit(Initialized { version });
        }
    }
}

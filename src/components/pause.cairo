// SPDX-License-Identifier: MPL-2.0
// CMTAT PauseModule: ERC-3643 pause and ERC-8343 deactivation.
// Pause and unpause require PAUSER_ROLE; deactivation requires DEFAULT_ADMIN_ROLE,
// requires the contract to be paused, and is irreversible (unpause is blocked).

#[starknet::component]
pub mod PauseComponent {
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::introspection::src5::SRC5Component::InternalImpl as SRC5InternalImpl;
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use crate::components::access::CMTATAccessControlComponent;
    use crate::components::access::CMTATAccessControlComponent::InternalImpl as AccessInternalImpl;
    use crate::errors;
    use crate::interfaces::pause::{IERC3643Pause, IERC8343, IERC8343_ID};
    use crate::roles::{DEFAULT_ADMIN_ROLE, PAUSER_ROLE};

    #[storage]
    pub struct Storage {
        pub PauseModule_paused: bool,
        pub PauseModule_deactivated: bool,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        Paused: Paused,
        Unpaused: Unpaused,
        Deactivated: Deactivated,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct Paused {
        pub account: ContractAddress,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct Unpaused {
        pub account: ContractAddress,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct Deactivated {
        #[key]
        pub account: ContractAddress,
    }

    #[embeddable_as(PauseImpl)]
    impl Pause<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        impl Access: CMTATAccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IERC3643Pause<ComponentState<TContractState>> {
        /// Pauses standard transfers. Requires PAUSER_ROLE and an unpaused contract.
        fn pause(ref self: ComponentState<TContractState>) {
            get_dep_component!(@self, Access).assert_only_role(PAUSER_ROLE);
            self.assert_not_paused();
            self.PauseModule_paused.write(true);
            self.emit(Paused { account: starknet::get_caller_address() });
        }

        /// Unpauses. Requires PAUSER_ROLE, a paused contract, and no deactivation.
        fn unpause(ref self: ComponentState<TContractState>) {
            get_dep_component!(@self, Access).assert_only_role(PAUSER_ROLE);
            assert(!self.PauseModule_deactivated.read(), errors::PAUSE_CONTRACT_IS_DEACTIVATED);
            self.assert_paused();
            self.PauseModule_paused.write(false);
            self.emit(Unpaused { account: starknet::get_caller_address() });
        }

        fn paused(self: @ComponentState<TContractState>) -> bool {
            self.PauseModule_paused.read()
        }
    }

    #[embeddable_as(ERC8343Impl)]
    impl ERC8343<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        impl Access: CMTATAccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IERC8343<ComponentState<TContractState>> {
        /// Permanently deactivates the contract. Requires DEFAULT_ADMIN_ROLE and a
        /// paused contract.
        fn deactivate_contract(ref self: ComponentState<TContractState>) {
            get_dep_component!(@self, Access).assert_only_role(DEFAULT_ADMIN_ROLE);
            self.assert_paused();
            assert(!self.PauseModule_deactivated.read(), errors::ALREADY_DEACTIVATED);
            self.PauseModule_deactivated.write(true);
            self.emit(Deactivated { account: starknet::get_caller_address() });
        }

        fn deactivated(self: @ComponentState<TContractState>) -> bool {
            self.PauseModule_deactivated.read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Registers the ERC-8343 interface id.
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5 = get_dep_component_mut!(ref self, SRC5);
            src5.register_interface(IERC8343_ID);
        }

        fn is_paused(self: @ComponentState<TContractState>) -> bool {
            self.PauseModule_paused.read()
        }

        fn is_deactivated(self: @ComponentState<TContractState>) -> bool {
            self.PauseModule_deactivated.read()
        }

        fn assert_not_paused(self: @ComponentState<TContractState>) {
            assert(!self.PauseModule_paused.read(), errors::ENFORCED_PAUSE);
        }

        fn assert_paused(self: @ComponentState<TContractState>) {
            assert(self.PauseModule_paused.read(), errors::EXPECTED_PAUSE);
        }

        fn assert_not_deactivated(self: @ComponentState<TContractState>) {
            assert(!self.PauseModule_deactivated.read(), errors::ENFORCED_DEACTIVATION);
        }
    }
}

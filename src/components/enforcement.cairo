// SPDX-License-Identifier: MPL-2.0
// CMTAT EnforcementModule: address freeze under ENFORCER_ROLE.

#[starknet::component]
pub mod EnforcementComponent {
    use core::num::traits::Zero;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use crate::components::access::CMTATAccessControlComponent;
    use crate::components::access::CMTATAccessControlComponent::InternalImpl as AccessInternalImpl;
    use crate::errors;
    use crate::interfaces::enforcement::{ICMTATEnforcement, IERC3643Enforcement};
    use crate::roles::ENFORCER_ROLE;

    #[storage]
    pub struct Storage {
        pub EnforcementModule_frozen: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        AddressFrozen: AddressFrozen,
    }

    /// Emitted on every freeze status update, including no-op updates.
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct AddressFrozen {
        #[key]
        pub account: ContractAddress,
        #[key]
        pub is_frozen: bool,
        #[key]
        pub enforcer: ContractAddress,
        pub data: Span<felt252>,
    }

    #[embeddable_as(EnforcementImpl)]
    impl Enforcement<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        impl Access: CMTATAccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IERC3643Enforcement<ComponentState<TContractState>> {
        fn set_address_frozen(
            ref self: ComponentState<TContractState>, account: ContractAddress, freeze: bool,
        ) {
            get_dep_component!(@self, Access).assert_only_role(ENFORCER_ROLE);
            self._set_address_frozen(account, freeze, array![].span());
        }

        fn batch_set_address_frozen(
            ref self: ComponentState<TContractState>,
            accounts: Span<ContractAddress>,
            freezes: Span<bool>,
        ) {
            get_dep_component!(@self, Access).assert_only_role(ENFORCER_ROLE);
            assert(accounts.len() > 0, errors::ENF_EMPTY_ACCOUNTS);
            assert(accounts.len() == freezes.len(), errors::ENF_ACCOUNTS_VALUES_LEN_MISMATCH);
            for i in 0..accounts.len() {
                self._set_address_frozen(*accounts[i], *freezes[i], array![].span());
            }
        }

        fn is_frozen(self: @ComponentState<TContractState>, account: ContractAddress) -> bool {
            self.EnforcementModule_frozen.read(account)
        }
    }

    #[embeddable_as(CMTATEnforcementImpl)]
    impl CMTATEnforcement<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        impl Access: CMTATAccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of ICMTATEnforcement<ComponentState<TContractState>> {
        fn set_address_frozen_with_data(
            ref self: ComponentState<TContractState>,
            account: ContractAddress,
            freeze: bool,
            data: Span<felt252>,
        ) {
            get_dep_component!(@self, Access).assert_only_role(ENFORCER_ROLE);
            self._set_address_frozen(account, freeze, data);
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn is_address_frozen(
            self: @ComponentState<TContractState>, account: ContractAddress,
        ) -> bool {
            self.EnforcementModule_frozen.read(account)
        }

        /// Sets the freeze status without an access check and emits `AddressFrozen`.
        fn _set_address_frozen(
            ref self: ComponentState<TContractState>,
            account: ContractAddress,
            freeze: bool,
            data: Span<felt252>,
        ) {
            assert(account.is_non_zero(), errors::ENF_ZERO_ADDRESS_NOT_ALLOWED);
            self.EnforcementModule_frozen.write(account, freeze);
            self
                .emit(
                    AddressFrozen {
                        account, is_frozen: freeze, enforcer: starknet::get_caller_address(), data,
                    },
                );
        }
    }
}

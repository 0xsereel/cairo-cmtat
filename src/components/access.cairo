// SPDX-License-Identifier: MPL-2.0
// CMTAT AccessControlModule: OpenZeppelin AccessControl where the default admin
// implicitly holds every role.

#[starknet::component]
pub mod CMTATAccessControlComponent {
    use core::num::traits::Zero;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::access::accesscontrol::AccessControlComponent::InternalImpl as AccessControlInternalImpl;
    use openzeppelin::interfaces::accesscontrol::IAccessControl;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use starknet::storage::StorageMapReadAccess;
    use crate::errors;
    use crate::roles::DEFAULT_ADMIN_ROLE;

    #[storage]
    pub struct Storage {}

    #[embeddable_as(AccessControlImpl)]
    impl AccessControl<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        impl AC: AccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IAccessControl<ComponentState<TContractState>> {
        /// Returns whether `account` holds `role`. The default admin holds every role.
        fn has_role(
            self: @ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) -> bool {
            InternalTrait::has_role(self, role, account)
        }

        fn get_role_admin(self: @ComponentState<TContractState>, role: felt252) -> felt252 {
            let access_control = get_dep_component!(self, AC);
            access_control.AccessControl_role_admin.read(role)
        }

        /// Grants `role` to `account`. The caller must hold `role`'s admin role.
        fn grant_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) {
            InternalTrait::assert_only_role(@self, Self::get_role_admin(@self, role));
            let mut access_control = get_dep_component_mut!(ref self, AC);
            access_control._grant_role(role, account);
        }

        /// Revokes `role` from `account`. The caller must hold `role`'s admin role.
        fn revoke_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) {
            InternalTrait::assert_only_role(@self, Self::get_role_admin(@self, role));
            let mut access_control = get_dep_component_mut!(ref self, AC);
            access_control._revoke_role(role, account);
        }

        /// Revokes `role` from the caller, who must be `account`.
        fn renounce_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) {
            assert(
                starknet::get_caller_address() == account,
                AccessControlComponent::Errors::INVALID_CALLER,
            );
            let mut access_control = get_dep_component_mut!(ref self, AC);
            access_control._revoke_role(role, account);
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        impl AC: AccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Registers the AccessControl interface and grants the default admin role to `admin`.
        fn initializer(ref self: ComponentState<TContractState>, admin: ContractAddress) {
            assert(admin.is_non_zero(), errors::ACCESS_CONTROL_ADDRESS_ZERO);
            let mut access_control = get_dep_component_mut!(ref self, AC);
            access_control.initializer();
            access_control._grant_role(DEFAULT_ADMIN_ROLE, admin);
        }

        fn has_role(
            self: @ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) -> bool {
            let access_control = get_dep_component!(self, AC);
            access_control.is_role_effective(DEFAULT_ADMIN_ROLE, account)
                || access_control.is_role_effective(role, account)
        }

        /// Panics with OpenZeppelin's `MISSING_ROLE` unless the caller holds `role`.
        fn assert_only_role(self: @ComponentState<TContractState>, role: felt252) {
            assert(
                InternalTrait::has_role(self, role, starknet::get_caller_address()),
                AccessControlComponent::Errors::MISSING_ROLE,
            );
        }
    }
}

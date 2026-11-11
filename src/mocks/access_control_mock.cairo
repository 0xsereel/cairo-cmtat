// SPDX-License-Identifier: MPL-2.0
// Mock embedding CMTATAccessControlComponent, with one MINTER_ROLE-guarded entry point.

#[starknet::interface]
pub trait IAccessControlMock<TState> {
    fn only_minter(self: @TState) -> bool;
}

#[starknet::contract]
pub mod AccessControlMock {
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use crate::components::access::CMTATAccessControlComponent;
    use crate::roles::MINTER_ROLE;

    component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(
        path: CMTATAccessControlComponent, storage: cmtat_access, event: CMTATAccessControlEvent,
    );

    #[abi(embed_v0)]
    impl AccessControlImpl =
        CMTATAccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = CMTATAccessControlComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        access_control: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        cmtat_access: CMTATAccessControlComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        CMTATAccessControlEvent: CMTATAccessControlComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.cmtat_access.initializer(admin);
    }

    #[abi(embed_v0)]
    impl MockImpl of super::IAccessControlMock<ContractState> {
        fn only_minter(self: @ContractState) -> bool {
            self.cmtat_access.assert_only_role(MINTER_ROLE);
            true
        }
    }
}

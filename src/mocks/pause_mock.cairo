// SPDX-License-Identifier: MPL-2.0
// Mock embedding PauseComponent, with entry points that exercise its guards.

#[starknet::interface]
pub trait IPauseMock<TState> {
    fn when_not_paused(self: @TState) -> bool;
    fn when_not_deactivated(self: @TState) -> bool;
}

#[starknet::contract]
pub mod PauseMock {
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use crate::components::access::CMTATAccessControlComponent;
    use crate::components::pause::PauseComponent;

    component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(
        path: CMTATAccessControlComponent, storage: cmtat_access, event: CMTATAccessControlEvent,
    );
    component!(path: PauseComponent, storage: pause, event: PauseEvent);

    #[abi(embed_v0)]
    impl AccessControlImpl =
        CMTATAccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = CMTATAccessControlComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl PauseImpl = PauseComponent::PauseImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC8343Impl = PauseComponent::ERC8343Impl<ContractState>;
    impl PauseInternalImpl = PauseComponent::InternalImpl<ContractState>;

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
        #[substorage(v0)]
        pause: PauseComponent::Storage,
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
        #[flat]
        PauseEvent: PauseComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.cmtat_access.initializer(admin);
        self.pause.initializer();
    }

    #[abi(embed_v0)]
    impl MockImpl of super::IPauseMock<ContractState> {
        fn when_not_paused(self: @ContractState) -> bool {
            self.pause.assert_not_paused();
            true
        }

        fn when_not_deactivated(self: @ContractState) -> bool {
            self.pause.assert_not_deactivated();
            true
        }
    }
}

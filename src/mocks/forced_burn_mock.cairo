// SPDX-License-Identifier: MPL-2.0
// Mock embedding ForcedBurnComponent with address freeze, as in the Light preset.

#[starknet::contract]
pub mod ForcedBurnMock {
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::{DefaultConfig, ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;
    use crate::components::access::CMTATAccessControlComponent;
    use crate::components::enforcement::EnforcementComponent;
    use crate::components::forced_burn::ForcedBurnComponent;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(
        path: CMTATAccessControlComponent, storage: cmtat_access, event: CMTATAccessControlEvent,
    );
    component!(path: EnforcementComponent, storage: enforcement, event: EnforcementEvent);
    component!(path: ForcedBurnComponent, storage: forced_burn, event: ForcedBurnEvent);

    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl AccessControlImpl =
        CMTATAccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = CMTATAccessControlComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl EnforcementImpl = EnforcementComponent::EnforcementImpl<ContractState>;
    #[abi(embed_v0)]
    impl ForcedBurnImpl = ForcedBurnComponent::ForcedBurnImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        access_control: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        cmtat_access: CMTATAccessControlComponent::Storage,
        #[substorage(v0)]
        enforcement: EnforcementComponent::Storage,
        #[substorage(v0)]
        forced_burn: ForcedBurnComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        CMTATAccessControlEvent: CMTATAccessControlComponent::Event,
        #[flat]
        EnforcementEvent: EnforcementComponent::Event,
        #[flat]
        ForcedBurnEvent: ForcedBurnComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        initial_supply: u256,
        recipient: ContractAddress,
        admin: ContractAddress,
    ) {
        self.erc20.initializer("Mock", "MCK");
        self.cmtat_access.initializer(admin);
        self.erc20.mint(recipient, initial_supply);
    }
}

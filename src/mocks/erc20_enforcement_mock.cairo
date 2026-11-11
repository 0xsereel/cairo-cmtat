// SPDX-License-Identifier: MPL-2.0
// Mock embedding ERC20EnforcementComponent over OpenZeppelin ERC-20, with an
// entry point that exercises the active-balance check.

use starknet::ContractAddress;

#[starknet::interface]
pub trait IERC20EnforcementMock<TState> {
    fn check_active_balance(self: @TState, from: ContractAddress, value: u256) -> bool;
}

#[starknet::contract]
pub mod ERC20EnforcementMock {
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::{DefaultConfig, ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;
    use crate::components::access::CMTATAccessControlComponent;
    use crate::components::erc20_base::ERC20BaseComponent;
    use crate::components::erc20_enforcement::ERC20EnforcementComponent;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(
        path: CMTATAccessControlComponent, storage: cmtat_access, event: CMTATAccessControlEvent,
    );
    component!(path: ERC20BaseComponent, storage: erc20_base, event: ERC20BaseEvent);
    component!(
        path: ERC20EnforcementComponent, storage: erc20_enforcement, event: ERC20EnforcementEvent,
    );

    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl AccessControlImpl =
        CMTATAccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = CMTATAccessControlComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl ERC3643ERC20EnforcementImpl =
        ERC20EnforcementComponent::ERC3643ERC20EnforcementImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC7943FungibleEnforcementImpl =
        ERC20EnforcementComponent::ERC7943FungibleEnforcementImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC7551ERC20EnforcementImpl =
        ERC20EnforcementComponent::ERC7551ERC20EnforcementImpl<ContractState>;
    impl ERC20EnforcementInternalImpl = ERC20EnforcementComponent::InternalImpl<ContractState>;

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
        erc20_base: ERC20BaseComponent::Storage,
        #[substorage(v0)]
        erc20_enforcement: ERC20EnforcementComponent::Storage,
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
        ERC20BaseEvent: ERC20BaseComponent::Event,
        #[flat]
        ERC20EnforcementEvent: ERC20EnforcementComponent::Event,
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

    #[abi(embed_v0)]
    impl MockImpl of super::IERC20EnforcementMock<ContractState> {
        fn check_active_balance(self: @ContractState, from: ContractAddress, value: u256) -> bool {
            self.erc20_enforcement.assert_active_balance(from, value);
            true
        }
    }
}

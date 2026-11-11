// SPDX-License-Identifier: MPL-2.0
// CMTATBaseCore `forcedBurn` (Light preset only; other presets use
// `forced_transfer(from, 0, value)`). Requires DEFAULT_ADMIN_ROLE and a frozen
// target, skips the check chain, and emits `ForcedTransfer` with `to == 0`.

#[starknet::component]
pub mod ForcedBurnComponent {
    use core::num::traits::Zero;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::ERC20Component;
    use openzeppelin::token::erc20::ERC20Component::InternalImpl as ERC20InternalImpl;
    use starknet::ContractAddress;
    use crate::components::access::CMTATAccessControlComponent;
    use crate::components::access::CMTATAccessControlComponent::InternalImpl as AccessInternalImpl;
    use crate::components::enforcement::EnforcementComponent;
    use crate::components::enforcement::EnforcementComponent::InternalImpl as EnforcementInternalImpl;
    use crate::errors;
    use crate::interfaces::burn::IForcedBurnERC20;
    use crate::roles::DEFAULT_ADMIN_ROLE;

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        ForcedTransfer: ForcedTransfer,
    }

    /// Same shape as ERC20EnforcementComponent's `ForcedTransfer`; the two
    /// components are never embedded together.
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct ForcedTransfer {
        #[key]
        pub operator: ContractAddress,
        #[key]
        pub from: ContractAddress,
        #[key]
        pub to: ContractAddress,
        pub value: u256,
        pub data: Span<felt252>,
    }

    #[embeddable_as(ForcedBurnImpl)]
    impl ForcedBurn<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC20: ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        impl Enforcement: EnforcementComponent::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        impl Access: CMTATAccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IForcedBurnERC20<ComponentState<TContractState>> {
        fn forced_burn(
            ref self: ComponentState<TContractState>,
            account: ContractAddress,
            value: u256,
            data: Span<felt252>,
        ) {
            get_dep_component!(@self, Access).assert_only_role(DEFAULT_ADMIN_ROLE);
            assert(
                get_dep_component!(@self, Enforcement).is_address_frozen(account),
                errors::BURN_ENF_ADDRESS_IS_NOT_FROZEN,
            );
            get_dep_component_mut!(ref self, ERC20).burn(account, value);
            self
                .emit(
                    ForcedTransfer {
                        operator: starknet::get_caller_address(),
                        from: account,
                        to: Zero::zero(),
                        value,
                        data,
                    },
                );
        }
    }
}

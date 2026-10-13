// SPDX-License-Identifier: MPL-2.0
// Check chains for ERC20BaseComponent, one per CMTAT base. A preset brings exactly
// one into scope.

use starknet::ContractAddress;
use crate::components::enforcement::EnforcementComponent;
use crate::components::erc20_base::ERC20BaseComponent;
use crate::components::erc20_base::ERC20BaseComponent::CMTATHooksTrait;
use crate::components::erc20_enforcement::ERC20EnforcementComponent;
use crate::components::erc20_enforcement::ERC20EnforcementComponent::InternalImpl as ERC20EnforcementInternalImpl;
use crate::components::pause::PauseComponent;
use crate::components::validation::ValidationComponent;
use crate::components::validation::ValidationComponent::InternalImpl as ValidationInternalImpl;

/// CMTATBaseCore (Light): module checks only; there is no partial freeze.
pub impl CoreHooksImpl<
    TContractState,
    +ERC20BaseComponent::HasComponent<TContractState>,
    impl Validation: ValidationComponent::HasComponent<TContractState>,
    +PauseComponent::HasComponent<TContractState>,
    +EnforcementComponent::HasComponent<TContractState>,
    +openzeppelin::introspection::src5::SRC5Component::HasComponent<TContractState>,
    +Drop<TContractState>,
> of CMTATHooksTrait<TContractState> {
    fn check_transferred(
        ref self: ERC20BaseComponent::ComponentState<TContractState>,
        spender: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        value: u256,
    ) {
        let contract = self.get_contract();
        Validation::get_component(contract).assert_can_transfer_generic(spender, from, to);
    }

    fn check_approve(
        self: @ERC20BaseComponent::ComponentState<TContractState>,
        owner: ContractAddress,
        spender: ContractAddress,
        value: u256,
    ) {
        let contract = self.get_contract();
        Validation::get_component(contract).assert_can_approve(owner, spender, value);
    }
}

/// CMTATBaseCommon: active balance first, then module checks.
pub impl CommonHooksImpl<
    TContractState,
    +ERC20BaseComponent::HasComponent<TContractState>,
    impl Validation: ValidationComponent::HasComponent<TContractState>,
    impl ERC20Enforcement: ERC20EnforcementComponent::HasComponent<TContractState>,
    +openzeppelin::token::erc20::ERC20Component::HasComponent<TContractState>,
    +openzeppelin::token::erc20::ERC20Component::ERC20HooksTrait<TContractState>,
    +PauseComponent::HasComponent<TContractState>,
    +EnforcementComponent::HasComponent<TContractState>,
    +openzeppelin::introspection::src5::SRC5Component::HasComponent<TContractState>,
    +Drop<TContractState>,
> of CMTATHooksTrait<TContractState> {
    fn check_transferred(
        ref self: ERC20BaseComponent::ComponentState<TContractState>,
        spender: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        value: u256,
    ) {
        let contract = self.get_contract();
        ERC20Enforcement::get_component(contract).assert_active_balance(from, value);
        Validation::get_component(contract).assert_can_transfer_generic(spender, from, to);
    }

    fn check_approve(
        self: @ERC20BaseComponent::ComponentState<TContractState>,
        owner: ContractAddress,
        spender: ContractAddress,
        value: u256,
    ) {
        let contract = self.get_contract();
        Validation::get_component(contract).assert_can_approve(owner, spender, value);
    }
}

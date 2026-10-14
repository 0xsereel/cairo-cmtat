// SPDX-License-Identifier: MPL-2.0
// Check chains for ERC20BaseComponent, one per CMTAT base. A preset brings exactly
// one into scope.

use starknet::ContractAddress;
use starknet::storage::{StorageMapReadAccess, StoragePointerReadAccess};
use crate::components::allowlist::AllowlistComponent;
use crate::components::allowlist::AllowlistComponent::InternalImpl as AllowlistInternalImpl;
use crate::components::enforcement::EnforcementComponent;
use crate::components::enforcement::EnforcementComponent::InternalImpl as EnforcementInternalImpl;
use crate::components::erc20_base::ERC20BaseComponent;
use crate::components::erc20_base::ERC20BaseComponent::CMTATHooksTrait;
use crate::components::erc20_enforcement::ERC20EnforcementComponent;
use crate::components::erc20_enforcement::ERC20EnforcementComponent::InternalImpl as ERC20EnforcementInternalImpl;
use crate::components::pause::PauseComponent;
use crate::components::pause::PauseComponent::InternalImpl as PauseInternalImpl;
use crate::components::rule_engine::RuleEngineComponent;
use crate::components::rule_engine::RuleEngineComponent::InternalImpl as RuleEngineInternalImpl;
use crate::components::snapshot::SnapshotComponent;
use crate::components::snapshot::SnapshotComponent::InternalImpl as SnapshotInternalImpl;
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

/// CMTATBaseRuleEngine: active balance, then module checks, then the RuleEngine's
/// `transferred` (under the reentrancy guard).
pub impl RuleEngineHooksImpl<
    TContractState,
    +ERC20BaseComponent::HasComponent<TContractState>,
    impl Validation: ValidationComponent::HasComponent<TContractState>,
    impl ERC20Enforcement: ERC20EnforcementComponent::HasComponent<TContractState>,
    impl RuleEngine: RuleEngineComponent::HasComponent<TContractState>,
    +openzeppelin::security::ReentrancyGuardComponent::HasComponent<TContractState>,
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
        let mut contract = self.get_contract_mut();
        ERC20Enforcement::get_component(@contract).assert_active_balance(from, value);
        Validation::get_component(@contract).assert_can_transfer_generic(spender, from, to);
        RuleEngine::get_component_mut(ref contract).transferred(spender, from, to, value);
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

/// CMTATBaseAllowlist: active balance, then the allowlist, then module checks.
/// Approvals require owner and spender to be listed (when enabled) and not frozen.
pub impl AllowlistHooksImpl<
    TContractState,
    +ERC20BaseComponent::HasComponent<TContractState>,
    impl Validation: ValidationComponent::HasComponent<TContractState>,
    impl ERC20Enforcement: ERC20EnforcementComponent::HasComponent<TContractState>,
    impl Allowlist: AllowlistComponent::HasComponent<TContractState>,
    impl Pause: PauseComponent::HasComponent<TContractState>,
    impl Enforcement: EnforcementComponent::HasComponent<TContractState>,
    +openzeppelin::token::erc20::ERC20Component::HasComponent<TContractState>,
    +openzeppelin::token::erc20::ERC20Component::ERC20HooksTrait<TContractState>,
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
        Allowlist::get_component(contract).assert_allowlisted_generic(spender, from, to);
        Validation::get_component(contract).assert_can_transfer_generic(spender, from, to);
    }

    fn check_approve(
        self: @ERC20BaseComponent::ComponentState<TContractState>,
        owner: ContractAddress,
        spender: ContractAddress,
        value: u256,
    ) {
        if value == 0 {
            return;
        }
        let contract = self.get_contract();
        Pause::get_component(contract).assert_not_paused();
        let allowlist = Allowlist::get_component(contract);
        let enforcement = Enforcement::get_component(contract);
        if !allowlist.is_allowed(owner) || enforcement.is_address_frozen(owner) {
            crate::errors::cannot_send(owner);
        }
        if !allowlist.is_allowed(spender) || enforcement.is_address_frozen(spender) {
            crate::errors::cannot_send(spender);
        }
    }
}

/// OpenZeppelin ERC-20 hook for presets with a SnapshotEngine (CMTATBaseSnapshot):
/// notifies the engine after every balance change.
pub impl SnapshotERC20HooksImpl<
    TContractState,
    impl Snapshot: SnapshotComponent::HasComponent<TContractState>,
    +openzeppelin::token::erc20::ERC20Component::HasComponent<TContractState>,
    +Drop<TContractState>,
> of openzeppelin::token::erc20::ERC20Component::ERC20HooksTrait<TContractState> {
    fn after_update(
        ref self: openzeppelin::token::erc20::ERC20Component::ComponentState<TContractState>,
        from: ContractAddress,
        recipient: ContractAddress,
        amount: u256,
    ) {
        let balance_from = self.ERC20_balances.read(from);
        let balance_to = self.ERC20_balances.read(recipient);
        let total_supply = self.ERC20_total_supply.read();
        let contract = self.get_contract();
        Snapshot::get_component(contract)
            .operate_on_transfer(from, recipient, amount, balance_from, balance_to, total_supply);
    }
}

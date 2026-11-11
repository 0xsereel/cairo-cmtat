// SPDX-License-Identifier: MPL-2.0
// CMTAT ValidationModuleRuleEngine: an optional external RuleEngine, set under
// DEFAULT_ADMIN_ROLE. The zero address means no engine.
//
// - Writes: `transferred` is called after the module checks on every transfer,
//   mint and burn, before balances move. Without a spender (plain `transfer`) the
//   engine's ERC-3643 `transferred(from, to, value)` is called; otherwise
//   `transferred_with_spender(spender, from, to, value)` with the operator. The
//   call runs inside OpenZeppelin's ReentrancyGuard, so an engine that reenters
//   the token reverts instead of being validated against pre-transfer balances.
// - Reads: `can_transfer` / `can_transfer_from` are active balance, then module
//   checks, then the engine (CMTATBaseRuleEngine).

#[starknet::component]
pub mod RuleEngineComponent {
    use core::num::traits::Zero;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::security::ReentrancyGuardComponent;
    use openzeppelin::security::ReentrancyGuardComponent::InternalImpl as ReentrancyGuardInternalImpl;
    use openzeppelin::token::erc20::ERC20Component;
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use crate::components::access::CMTATAccessControlComponent;
    use crate::components::access::CMTATAccessControlComponent::InternalImpl as AccessInternalImpl;
    use crate::components::enforcement::EnforcementComponent;
    use crate::components::erc20_base::ERC20BaseComponent;
    use crate::components::erc20_enforcement::ERC20EnforcementComponent;
    use crate::components::erc20_enforcement::ERC20EnforcementComponent::InternalImpl as ERC20EnforcementInternalImpl;
    use crate::components::pause::PauseComponent;
    use crate::components::validation::ValidationComponent;
    use crate::components::validation::ValidationComponent::InternalImpl as ValidationInternalImpl;
    use crate::errors;
    use crate::interfaces::rule_engine::{
        IRuleEngineDispatcher, IRuleEngineDispatcherTrait, IValidationRuleEngine,
    };
    use crate::interfaces::validation::{IERC3643ComplianceRead, IERC7551Compliance};
    use crate::roles::DEFAULT_ADMIN_ROLE;

    #[storage]
    pub struct Storage {
        pub ValidationModuleRuleEngine_rule_engine: ContractAddress,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        RuleEngine: RuleEngineSet,
    }

    /// CMTAT `RuleEngine(IRuleEngine indexed newRuleEngine)`.
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct RuleEngineSet {
        #[key]
        pub new_rule_engine: ContractAddress,
    }

    #[embeddable_as(ValidationRuleEngineImpl)]
    impl ValidationRuleEngine<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        impl Access: CMTATAccessControlComponent::HasComponent<TContractState>,
        +ReentrancyGuardComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IValidationRuleEngine<ComponentState<TContractState>> {
        fn rule_engine(self: @ComponentState<TContractState>) -> ContractAddress {
            self.ValidationModuleRuleEngine_rule_engine.read()
        }

        fn set_rule_engine(ref self: ComponentState<TContractState>, rule_engine: ContractAddress) {
            get_dep_component!(@self, Access).assert_only_role(DEFAULT_ADMIN_ROLE);
            assert(
                rule_engine != self.ValidationModuleRuleEngine_rule_engine.read(),
                errors::VALIDATION_SAME_VALUE,
            );
            self._set_rule_engine(rule_engine);
        }
    }

    #[embeddable_as(ComplianceReadImpl)]
    impl ComplianceRead<
        TContractState,
        +HasComponent<TContractState>,
        impl Validation: ValidationComponent::HasComponent<TContractState>,
        +PauseComponent::HasComponent<TContractState>,
        +EnforcementComponent::HasComponent<TContractState>,
        +ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        +ERC20BaseComponent::HasComponent<TContractState>,
        impl ERC20Enforcement: ERC20EnforcementComponent::HasComponent<TContractState>,
        +ReentrancyGuardComponent::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IERC3643ComplianceRead<ComponentState<TContractState>> {
        fn can_transfer(
            self: @ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
        ) -> bool {
            let (is_valid, _) = get_dep_component!(self, ERC20Enforcement)
                .check_active_balance(from, value);
            if !is_valid
                || !get_dep_component!(self, Validation)
                    .can_transfer_generic(Zero::zero(), from, to) {
                return false;
            }
            let engine = self.ValidationModuleRuleEngine_rule_engine.read();
            engine.is_zero()
                || IRuleEngineDispatcher { contract_address: engine }.can_transfer(from, to, value)
        }
    }

    #[embeddable_as(ComplianceReadFromImpl)]
    impl ComplianceReadFrom<
        TContractState,
        +HasComponent<TContractState>,
        impl Validation: ValidationComponent::HasComponent<TContractState>,
        +PauseComponent::HasComponent<TContractState>,
        +EnforcementComponent::HasComponent<TContractState>,
        +ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        +ERC20BaseComponent::HasComponent<TContractState>,
        impl ERC20Enforcement: ERC20EnforcementComponent::HasComponent<TContractState>,
        +ReentrancyGuardComponent::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IERC7551Compliance<ComponentState<TContractState>> {
        fn can_transfer_from(
            self: @ComponentState<TContractState>,
            spender: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
        ) -> bool {
            let (is_valid, _) = get_dep_component!(self, ERC20Enforcement)
                .check_active_balance(from, value);
            if !is_valid
                || !get_dep_component!(self, Validation).can_transfer_generic(spender, from, to) {
                return false;
            }
            let engine = self.ValidationModuleRuleEngine_rule_engine.read();
            engine.is_zero()
                || IRuleEngineDispatcher { contract_address: engine }
                    .can_transfer_from(spender, from, to, value)
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl Guard: ReentrancyGuardComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Sets the engine at deployment; the zero address leaves it unset.
        fn initializer(ref self: ComponentState<TContractState>, rule_engine: ContractAddress) {
            if rule_engine.is_non_zero() {
                self._set_rule_engine(rule_engine);
            }
        }

        fn get_rule_engine(self: @ComponentState<TContractState>) -> ContractAddress {
            self.ValidationModuleRuleEngine_rule_engine.read()
        }

        fn _set_rule_engine(
            ref self: ComponentState<TContractState>, rule_engine: ContractAddress,
        ) {
            self.ValidationModuleRuleEngine_rule_engine.write(rule_engine);
            self.emit(RuleEngineSet { new_rule_engine: rule_engine });
        }

        /// CMTAT `_callRuleEngineTransferred`, under the reentrancy guard.
        fn transferred(
            ref self: ComponentState<TContractState>,
            spender: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
        ) {
            let engine = self.ValidationModuleRuleEngine_rule_engine.read();
            if engine.is_zero() {
                return;
            }
            let mut guard = get_dep_component_mut!(ref self, Guard);
            guard.start();
            let dispatcher = IRuleEngineDispatcher { contract_address: engine };
            if spender.is_zero() {
                dispatcher.transferred(from, to, value);
            } else {
                dispatcher.transferred_with_spender(spender, from, to, value);
            }
            let mut guard = get_dep_component_mut!(ref self, Guard);
            guard.end();
        }
    }
}

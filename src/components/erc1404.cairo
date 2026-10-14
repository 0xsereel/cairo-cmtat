// SPDX-License-Identifier: MPL-2.0
// CMTAT ValidationModuleERC1404 + CMTATBaseERC1404: restriction codes and messages.
//
// Read order (deliberately different from the revert path, as in CMTAT):
// spender frozen (5, `_from` only), insufficient active balance (6), deactivated
// (1), paused (2), from frozen (3), to frozen (4), then the RuleEngine if one is
// set (codes 7-12 and their messages), otherwise 0.

#[starknet::component]
pub mod ERC1404Component {
    use core::num::traits::Zero;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::security::ReentrancyGuardComponent;
    use openzeppelin::token::erc20::ERC20Component;
    use starknet::ContractAddress;
    use crate::components::enforcement::EnforcementComponent;
    use crate::components::enforcement::EnforcementComponent::InternalImpl as EnforcementInternalImpl;
    use crate::components::erc20_base::ERC20BaseComponent;
    use crate::components::erc20_enforcement::ERC20EnforcementComponent;
    use crate::components::erc20_enforcement::ERC20EnforcementComponent::InternalImpl as ERC20EnforcementInternalImpl;
    use crate::components::pause::PauseComponent;
    use crate::components::pause::PauseComponent::InternalImpl as PauseInternalImpl;
    use crate::components::rule_engine::RuleEngineComponent;
    use crate::components::rule_engine::RuleEngineComponent::InternalImpl as RuleEngineInternalImpl;
    use crate::interfaces::erc1404::{
        IERC1404, IERC1404Extend, TRANSFER_OK, TRANSFER_REJECTED_DEACTIVATED,
        TRANSFER_REJECTED_FROM_FROZEN, TRANSFER_REJECTED_FROM_INSUFFICIENT_ACTIVE_BALANCE,
        TRANSFER_REJECTED_PAUSED, TRANSFER_REJECTED_SPENDER_FROZEN, TRANSFER_REJECTED_TO_FROZEN,
    };
    use crate::interfaces::rule_engine::{
        IRuleEngineERC1404Dispatcher, IRuleEngineERC1404DispatcherTrait,
    };

    #[storage]
    pub struct Storage {}

    #[embeddable_as(ERC1404Impl)]
    impl ERC1404<
        TContractState,
        +HasComponent<TContractState>,
        +PauseComponent::HasComponent<TContractState>,
        +EnforcementComponent::HasComponent<TContractState>,
        +ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        +ERC20BaseComponent::HasComponent<TContractState>,
        +ERC20EnforcementComponent::HasComponent<TContractState>,
        impl RuleEngine: RuleEngineComponent::HasComponent<TContractState>,
        +ReentrancyGuardComponent::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IERC1404<ComponentState<TContractState>> {
        fn detect_transfer_restriction(
            self: @ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
        ) -> u8 {
            let code = self.detect(from, to, value);
            let engine = get_dep_component!(self, RuleEngine).get_rule_engine();
            if code != TRANSFER_OK || engine.is_zero() {
                return code;
            }
            IRuleEngineERC1404Dispatcher { contract_address: engine }
                .detect_transfer_restriction(from, to, value)
        }

        fn message_for_transfer_restriction(
            self: @ComponentState<TContractState>, restriction_code: u8,
        ) -> ByteArray {
            if restriction_code == TRANSFER_OK {
                "NoRestriction"
            } else if restriction_code == TRANSFER_REJECTED_DEACTIVATED {
                "ContractDeactivated"
            } else if restriction_code == TRANSFER_REJECTED_PAUSED {
                "EnforcedPause"
            } else if restriction_code == TRANSFER_REJECTED_FROM_FROZEN {
                "AddrFromIsFrozen"
            } else if restriction_code == TRANSFER_REJECTED_TO_FROZEN {
                "AddrToIsFrozen"
            } else if restriction_code == TRANSFER_REJECTED_SPENDER_FROZEN {
                "AddrSpenderIsFrozen"
            } else if restriction_code == TRANSFER_REJECTED_FROM_INSUFFICIENT_ACTIVE_BALANCE {
                "AddrFrom:insufficientActiveBalance"
            } else {
                let engine = get_dep_component!(self, RuleEngine).get_rule_engine();
                if engine.is_zero() {
                    "UnknownCode"
                } else {
                    IRuleEngineERC1404Dispatcher { contract_address: engine }
                        .message_for_transfer_restriction(restriction_code)
                }
            }
        }
    }

    #[embeddable_as(ERC1404ExtendImpl)]
    impl ERC1404Extend<
        TContractState,
        +HasComponent<TContractState>,
        +PauseComponent::HasComponent<TContractState>,
        impl Enforcement: EnforcementComponent::HasComponent<TContractState>,
        +ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        +ERC20BaseComponent::HasComponent<TContractState>,
        +ERC20EnforcementComponent::HasComponent<TContractState>,
        impl RuleEngine: RuleEngineComponent::HasComponent<TContractState>,
        +ReentrancyGuardComponent::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IERC1404Extend<ComponentState<TContractState>> {
        fn detect_transfer_restriction_from(
            self: @ComponentState<TContractState>,
            spender: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
        ) -> u8 {
            if get_dep_component!(self, Enforcement).is_address_frozen(spender) {
                return TRANSFER_REJECTED_SPENDER_FROZEN;
            }
            let code = self.detect(from, to, value);
            let engine = get_dep_component!(self, RuleEngine).get_rule_engine();
            if code != TRANSFER_OK || engine.is_zero() {
                return code;
            }
            IRuleEngineERC1404Dispatcher { contract_address: engine }
                .detect_transfer_restriction_from(spender, from, to, value)
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl Pause: PauseComponent::HasComponent<TContractState>,
        impl Enforcement: EnforcementComponent::HasComponent<TContractState>,
        +ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        +ERC20BaseComponent::HasComponent<TContractState>,
        impl ERC20Enforcement: ERC20EnforcementComponent::HasComponent<TContractState>,
        +RuleEngineComponent::HasComponent<TContractState>,
        +ReentrancyGuardComponent::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// `_detectTransferRestriction`: active balance first, then module state.
        fn detect(
            self: @ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
        ) -> u8 {
            let (is_valid, _) = get_dep_component!(self, ERC20Enforcement)
                .check_active_balance(from, value);
            if !is_valid {
                return TRANSFER_REJECTED_FROM_INSUFFICIENT_ACTIVE_BALANCE;
            }
            let pause = get_dep_component!(self, Pause);
            let enforcement = get_dep_component!(self, Enforcement);
            if pause.is_deactivated() {
                TRANSFER_REJECTED_DEACTIVATED
            } else if pause.is_paused() {
                TRANSFER_REJECTED_PAUSED
            } else if enforcement.is_address_frozen(from) {
                TRANSFER_REJECTED_FROM_FROZEN
            } else if enforcement.is_address_frozen(to) {
                TRANSFER_REJECTED_TO_FROZEN
            } else {
                TRANSFER_OK
            }
        }
    }
}

// SPDX-License-Identifier: MPL-2.0
// CMTAT ERC20EnforcementModule (+ ERC20EnforcementERC7551Module): partial token
// freeze under ERC20ENFORCER_ROLE and forced transfer under DEFAULT_ADMIN_ROLE.
//
// Events: Solidity emits both an ERC-3643 `TokensFrozen(account, value)` and an
// ERC-7551 `TokensFrozen(account, value, data)` (same for `TokensUnfrozen` and the
// ERC-7943 / ERC-7551 `ForcedTransfer`). Starknet keys events by name only, so each
// pair is one event here, carrying `data` (empty on the plain entry points) and,
// for `ForcedTransfer`, the operator. `Spend` is emitted through ERC20BaseComponent.

#[starknet::component]
pub mod ERC20EnforcementComponent {
    use core::num::traits::{Bounded, Zero};
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::ERC20Component;
    use openzeppelin::token::erc20::ERC20Component::InternalImpl as ERC20InternalImpl;
    use starknet::ContractAddress;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use crate::components::access::CMTATAccessControlComponent;
    use crate::components::access::CMTATAccessControlComponent::InternalImpl as AccessInternalImpl;
    use crate::components::erc20_base::ERC20BaseComponent;
    use crate::components::erc20_base::ERC20BaseComponent::InternalImpl as ERC20BaseInternalImpl;
    use crate::errors;
    use crate::interfaces::erc20_enforcement::{
        IERC3643ERC20Enforcement, IERC7551ERC20Enforcement, IERC7943FungibleEnforcement,
    };
    use crate::roles::{DEFAULT_ADMIN_ROLE, ERC20ENFORCER_ROLE};

    #[storage]
    pub struct Storage {
        pub ERC20EnforcementModule_frozen_tokens: Map<ContractAddress, u256>,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        TokensFrozen: TokensFrozen,
        TokensUnfrozen: TokensUnfrozen,
        Frozen: Frozen,
        ForcedTransfer: ForcedTransfer,
    }

    /// `value` tokens of `account` were frozen.
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct TokensFrozen {
        #[key]
        pub account: ContractAddress,
        pub value: u256,
        pub data: Span<felt252>,
    }

    /// `value` tokens of `account` were unfrozen.
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct TokensUnfrozen {
        #[key]
        pub account: ContractAddress,
        pub value: u256,
        pub data: Span<felt252>,
    }

    /// ERC-7943: the frozen amount of `account` is now `amount`.
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct Frozen {
        #[key]
        pub account: ContractAddress,
        pub amount: u256,
    }

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

    #[embeddable_as(ERC3643ERC20EnforcementImpl)]
    impl ERC3643ERC20Enforcement<
        TContractState,
        +HasComponent<TContractState>,
        +ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        +ERC20BaseComponent::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        impl Access: CMTATAccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IERC3643ERC20Enforcement<ComponentState<TContractState>> {
        fn freeze_partial_tokens(
            ref self: ComponentState<TContractState>, account: ContractAddress, value: u256,
        ) {
            get_dep_component!(@self, Access).assert_only_role(ERC20ENFORCER_ROLE);
            self._freeze_partial_tokens(account, value, array![].span());
        }

        fn unfreeze_partial_tokens(
            ref self: ComponentState<TContractState>, account: ContractAddress, value: u256,
        ) {
            get_dep_component!(@self, Access).assert_only_role(ERC20ENFORCER_ROLE);
            self._unfreeze_partial_tokens(account, value, array![].span());
        }
    }

    #[embeddable_as(ERC7943FungibleEnforcementImpl)]
    impl ERC7943FungibleEnforcement<
        TContractState,
        +HasComponent<TContractState>,
        +ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        +ERC20BaseComponent::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        impl Access: CMTATAccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IERC7943FungibleEnforcement<ComponentState<TContractState>> {
        fn get_frozen_tokens(
            self: @ComponentState<TContractState>, account: ContractAddress,
        ) -> u256 {
            self.ERC20EnforcementModule_frozen_tokens.read(account)
        }

        /// Sets the frozen amount of `account` to `value`. Unlike partial freeze,
        /// `value` may exceed the balance.
        fn set_frozen_tokens(
            ref self: ComponentState<TContractState>, account: ContractAddress, value: u256,
        ) -> bool {
            get_dep_component!(@self, Access).assert_only_role(ERC20ENFORCER_ROLE);
            assert(account.is_non_zero(), errors::ERC20ENF_ZERO_ADDRESS_NOT_ALLOWED);
            let current = self.ERC20EnforcementModule_frozen_tokens.read(account);
            assert(value != current, errors::ERC20ENF_VALUE_EQ_CURRENT_FROZEN);
            self.ERC20EnforcementModule_frozen_tokens.write(account, value);
            let data = array![].span();
            self.emit(Frozen { account, amount: value });
            if value < current {
                self.emit(TokensUnfrozen { account, value: current - value, data });
            } else {
                self.emit(TokensFrozen { account, value: value - current, data });
            }
            true
        }

        fn forced_transfer(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
        ) -> bool {
            get_dep_component!(@self, Access).assert_only_role(DEFAULT_ADMIN_ROLE);
            self._forced_transfer(from, to, value, array![].span());
            true
        }
    }

    #[embeddable_as(ERC7551ERC20EnforcementImpl)]
    impl ERC7551ERC20Enforcement<
        TContractState,
        +HasComponent<TContractState>,
        +ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        +ERC20BaseComponent::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        impl Access: CMTATAccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IERC7551ERC20Enforcement<ComponentState<TContractState>> {
        fn get_active_balance_of(
            self: @ComponentState<TContractState>, account: ContractAddress,
        ) -> u256 {
            self.active_balance_of(account)
        }

        fn freeze_partial_tokens_with_data(
            ref self: ComponentState<TContractState>,
            account: ContractAddress,
            value: u256,
            data: Span<felt252>,
        ) {
            get_dep_component!(@self, Access).assert_only_role(ERC20ENFORCER_ROLE);
            self._freeze_partial_tokens(account, value, data);
        }

        fn unfreeze_partial_tokens_with_data(
            ref self: ComponentState<TContractState>,
            account: ContractAddress,
            value: u256,
            data: Span<felt252>,
        ) {
            get_dep_component!(@self, Access).assert_only_role(ERC20ENFORCER_ROLE);
            self._unfreeze_partial_tokens(account, value, data);
        }

        fn forced_transfer_with_data(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
            data: Span<felt252>,
        ) -> bool {
            get_dep_component!(@self, Access).assert_only_role(DEFAULT_ADMIN_ROLE);
            self._forced_transfer(from, to, value, data);
            true
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC20: ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        impl ERC20Base: ERC20BaseComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn frozen_tokens(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            self.ERC20EnforcementModule_frozen_tokens.read(account)
        }

        /// Balance minus frozen tokens, floored at zero.
        fn active_balance_of(
            self: @ComponentState<TContractState>, account: ContractAddress,
        ) -> u256 {
            let balance = self.balance_of(account);
            let frozen = self.ERC20EnforcementModule_frozen_tokens.read(account);
            if frozen >= balance {
                0
            } else {
                balance - frozen
            }
        }

        /// Returns whether `from` can debit `value` without touching frozen tokens,
        /// and its active balance. A zero-value debit is always valid.
        fn check_active_balance(
            self: @ComponentState<TContractState>, from: ContractAddress, value: u256,
        ) -> (bool, u256) {
            let frozen = self.ERC20EnforcementModule_frozen_tokens.read(from);
            if frozen == 0 {
                return (true, 0);
            }
            let active = self.active_balance_of(from);
            (value <= active, active)
        }

        /// Panics with `ERC7943InsufficientUnfrozenBal(from, value, active)` if `from`
        /// cannot debit `value` from its active balance.
        fn assert_active_balance(
            self: @ComponentState<TContractState>, from: ContractAddress, value: u256,
        ) {
            let (is_valid, active) = self.check_active_balance(from, value);
            if !is_valid {
                let mut panic_data = array![errors::ERC7943_INSUFFICIENT_UNFROZEN_BAL];
                from.serialize(ref panic_data);
                value.serialize(ref panic_data);
                active.serialize(ref panic_data);
                panic(panic_data);
            }
        }

        fn _freeze_partial_tokens(
            ref self: ComponentState<TContractState>,
            account: ContractAddress,
            value: u256,
            data: Span<felt252>,
        ) {
            assert(account.is_non_zero(), errors::ERC20ENF_ZERO_ADDRESS_NOT_ALLOWED);
            let frozen = self.ERC20EnforcementModule_frozen_tokens.read(account) + value;
            assert(self.balance_of(account) >= frozen, errors::ERC20ENF_VALUE_EXCEEDS_AVAIL_BAL);
            self.ERC20EnforcementModule_frozen_tokens.write(account, frozen);
            self.emit(Frozen { account, amount: frozen });
            self.emit(TokensFrozen { account, value, data });
        }

        fn _unfreeze_partial_tokens(
            ref self: ComponentState<TContractState>,
            account: ContractAddress,
            value: u256,
            data: Span<felt252>,
        ) {
            assert(account.is_non_zero(), errors::ERC20ENF_ZERO_ADDRESS_NOT_ALLOWED);
            let current = self.ERC20EnforcementModule_frozen_tokens.read(account);
            assert(current >= value, errors::ERC20ENF_VALUE_EXCEEDS_FROZEN_BAL);
            let frozen = current - value;
            self.ERC20EnforcementModule_frozen_tokens.write(account, frozen);
            self.emit(Frozen { account, amount: frozen });
            self.emit(TokensUnfrozen { account, value, data });
        }

        /// Unfreezes just enough of `account`'s frozen tokens to cover a debit of `value`.
        fn _unfreeze_tokens_for_debit(
            ref self: ComponentState<TContractState>,
            account: ContractAddress,
            value: u256,
            data: Span<felt252>,
        ) {
            assert(value <= self.balance_of(account), errors::ERC20ENF_VALUE_EXCEEDS_AVAIL_BAL);
            let active = self.active_balance_of(account);
            if value > active {
                let to_unfreeze = value - active;
                let frozen = self.ERC20EnforcementModule_frozen_tokens.read(account) - to_unfreeze;
                self.ERC20EnforcementModule_frozen_tokens.write(account, frozen);
                self.emit(Frozen { account, amount: frozen });
                self.emit(TokensUnfrozen { account, value: to_unfreeze, data });
            }
        }

        /// Forced transfer without an access check or compliance checks. Consumes
        /// frozen tokens as needed and any `from -> to` allowance (emitting `Spend`,
        /// not `Approval`). `to == 0` burns.
        fn _forced_transfer(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
            data: Span<felt252>,
        ) {
            assert(from != to, errors::ERC20ENF_SELF_TRANSFER_NOT_ALLOWED);
            self._unfreeze_tokens_for_debit(from, value, data);
            let mut erc20 = get_dep_component_mut!(ref self, ERC20);
            if to.is_zero() {
                erc20.burn(from, value);
            } else {
                let allowance = erc20.ERC20_allowances.read((from, to));
                if allowance > 0 && allowance < Bounded::MAX {
                    let spent = if allowance < value {
                        allowance
                    } else {
                        value
                    };
                    erc20.ERC20_allowances.write((from, to), allowance - spent);
                    get_dep_component_mut!(ref self, ERC20Base).emit_spend(from, to, spent);
                }
                let mut erc20 = get_dep_component_mut!(ref self, ERC20);
                erc20._transfer(from, to, value);
            }
            self
                .emit(
                    ForcedTransfer {
                        operator: starknet::get_caller_address(), from, to, value, data,
                    },
                );
        }

        fn balance_of(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            let erc20 = get_dep_component!(self, ERC20);
            erc20.ERC20_balances.read(account)
        }
    }
}

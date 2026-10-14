// SPDX-License-Identifier: MPL-2.0
// CMTAT AllowlistModule + ValidationModuleAllowlist. Management requires
// ALLOWLIST_ROLE. The allowlist is enabled at initialization.
//
// When enabled, the allowlist runs before the pause / freeze module checks:
// - standard transfer: spender (if non-zero), from, to must be listed;
// - mint: `to`; burn: `from`;
// - approve, `can_send`, `can_receive`: the account must be listed and not frozen.
// Failures revert with `ERC7943CannotSend` / `ERC7943CannotReceive`.

#[starknet::component]
pub mod AllowlistComponent {
    use core::num::traits::Zero;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::ERC20Component;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use crate::components::access::CMTATAccessControlComponent;
    use crate::components::access::CMTATAccessControlComponent::InternalImpl as AccessInternalImpl;
    use crate::components::enforcement::EnforcementComponent;
    use crate::components::enforcement::EnforcementComponent::InternalImpl as EnforcementInternalImpl;
    use crate::components::erc20_base::ERC20BaseComponent;
    use crate::components::erc20_enforcement::ERC20EnforcementComponent;
    use crate::components::erc20_enforcement::ERC20EnforcementComponent::InternalImpl as ERC20EnforcementInternalImpl;
    use crate::components::pause::PauseComponent;
    use crate::components::validation::ValidationComponent;
    use crate::components::validation::ValidationComponent::InternalImpl as ValidationInternalImpl;
    use crate::errors;
    use crate::interfaces::allowlist::IAllowlistModule;
    use crate::interfaces::validation::{
        IERC3643ComplianceRead, IERC7551Compliance, IERC7943FungibleSendReceiveCheck,
    };
    use crate::roles::ALLOWLIST_ROLE;

    #[storage]
    pub struct Storage {
        pub AllowlistModule_enabled: bool,
        pub AllowlistModule_list: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        AddressAddedToAllowlist: AddressAddedToAllowlist,
        AllowlistEnableStatus: AllowlistEnableStatus,
    }

    /// Emitted on every status update, including removals (`status == false`).
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct AddressAddedToAllowlist {
        #[key]
        pub account: ContractAddress,
        #[key]
        pub status: bool,
        #[key]
        pub enforcer: ContractAddress,
        pub data: Span<felt252>,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct AllowlistEnableStatus {
        #[key]
        pub operator: ContractAddress,
        pub status: bool,
    }

    #[embeddable_as(AllowlistImpl)]
    impl Allowlist<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        impl Access: CMTATAccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IAllowlistModule<ComponentState<TContractState>> {
        fn set_address_allowlist(
            ref self: ComponentState<TContractState>, account: ContractAddress, status: bool,
        ) {
            get_dep_component!(@self, Access).assert_only_role(ALLOWLIST_ROLE);
            self._set_allowlisted(account, status, array![].span());
        }

        fn set_address_allowlist_with_data(
            ref self: ComponentState<TContractState>,
            account: ContractAddress,
            status: bool,
            data: Span<felt252>,
        ) {
            get_dep_component!(@self, Access).assert_only_role(ALLOWLIST_ROLE);
            self._set_allowlisted(account, status, data);
        }

        fn batch_set_address_allowlist(
            ref self: ComponentState<TContractState>,
            accounts: Span<ContractAddress>,
            statuses: Span<bool>,
        ) {
            get_dep_component!(@self, Access).assert_only_role(ALLOWLIST_ROLE);
            assert(accounts.len() > 0, errors::ENF_EMPTY_ACCOUNTS);
            assert(accounts.len() == statuses.len(), errors::ENF_ACCOUNTS_VALUES_LEN_MISMATCH);
            for i in 0..accounts.len() {
                self._set_allowlisted(*accounts[i], *statuses[i], array![].span());
            }
        }

        fn enable_allowlist(ref self: ComponentState<TContractState>, status: bool) {
            get_dep_component!(@self, Access).assert_only_role(ALLOWLIST_ROLE);
            self.AllowlistModule_enabled.write(status);
            self.emit(AllowlistEnableStatus { operator: starknet::get_caller_address(), status });
        }

        fn is_allowlist_enabled(self: @ComponentState<TContractState>) -> bool {
            self.AllowlistModule_enabled.read()
        }

        fn is_allowlisted(self: @ComponentState<TContractState>, account: ContractAddress) -> bool {
            self.AllowlistModule_list.read(account)
        }
    }

    /// `can_send` / `can_receive`: listed (when enabled) and not frozen.
    #[embeddable_as(ERC7943SendReceiveImpl)]
    impl ERC7943SendReceive<
        TContractState,
        +HasComponent<TContractState>,
        impl Enforcement: EnforcementComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IERC7943FungibleSendReceiveCheck<ComponentState<TContractState>> {
        fn can_send(self: @ComponentState<TContractState>, account: ContractAddress) -> bool {
            self.is_allowed(account)
                && !get_dep_component!(self, Enforcement).is_address_frozen(account)
        }

        fn can_receive(self: @ComponentState<TContractState>, account: ContractAddress) -> bool {
            self.is_allowed(account)
                && !get_dep_component!(self, Enforcement).is_address_frozen(account)
        }
    }

    /// CMTATBaseAllowlist reads: active balance, allowlist, then module checks.
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
            is_valid
                && self.can_transfer_generic(Zero::zero(), from, to)
                && get_dep_component!(self, Validation).can_transfer_generic(Zero::zero(), from, to)
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
            is_valid
                && self.can_transfer_generic(spender, from, to)
                && get_dep_component!(self, Validation).can_transfer_generic(spender, from, to)
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Enables the allowlist, as CMTAT does at initialization.
        fn initializer(ref self: ComponentState<TContractState>) {
            self.AllowlistModule_enabled.write(true);
        }

        /// True when the allowlist is disabled or `account` is listed.
        fn is_allowed(self: @ComponentState<TContractState>, account: ContractAddress) -> bool {
            !self.AllowlistModule_enabled.read() || self.AllowlistModule_list.read(account)
        }

        fn _set_allowlisted(
            ref self: ComponentState<TContractState>,
            account: ContractAddress,
            status: bool,
            data: Span<felt252>,
        ) {
            self.AllowlistModule_list.write(account, status);
            self
                .emit(
                    AddressAddedToAllowlist {
                        account, status, enforcer: starknet::get_caller_address(), data,
                    },
                );
        }

        /// Allowlist part of the generic check: `from == 0` is a mint, `to == 0` a
        /// burn, anything else a standard transfer.
        fn assert_allowlisted_generic(
            self: @ComponentState<TContractState>,
            spender: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
        ) {
            if from.is_zero() {
                if !self.is_allowed(to) {
                    errors::cannot_receive(to);
                }
            } else if to.is_zero() {
                if !self.is_allowed(from) {
                    errors::cannot_send(from);
                }
            } else {
                if spender.is_non_zero() && !self.is_allowed(spender) {
                    errors::cannot_send(spender);
                }
                if !self.is_allowed(from) {
                    errors::cannot_send(from);
                }
                if !self.is_allowed(to) {
                    errors::cannot_receive(to);
                }
            }
        }

        fn can_transfer_generic(
            self: @ComponentState<TContractState>,
            spender: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
        ) -> bool {
            if from.is_zero() {
                self.is_allowed(to)
            } else if to.is_zero() {
                self.is_allowed(from)
            } else {
                (spender.is_zero() || self.is_allowed(spender))
                    && self.is_allowed(from)
                    && self.is_allowed(to)
            }
        }
    }
}

// SPDX-License-Identifier: MPL-2.0
// CMTAT ValidationModule: the pause / freeze / deactivation checks that gate
// transfers, mints, burns and approvals. Revert order follows CMTAT v3.3.0:
// - standard transfer: paused, then spender, from, to frozen (deactivation is not
//   checked: a deactivated contract is always paused);
// - mint: deactivated, then `to` frozen (pause does not block mint);
// - burn: deactivated, then `from` frozen (pause does not block burn);
// - approve: a zero value always passes; otherwise paused, then owner, spender frozen.
//
// Read impls: ERC7943SendReceiveImpl (`can_send` / `can_receive`: not frozen),
// ComplianceReadCoreImpl (Light: module checks only) and ComplianceReadCommonImpl
// (other presets: active balance, then module checks).

#[starknet::component]
pub mod ValidationComponent {
    use core::num::traits::Zero;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use crate::components::enforcement::EnforcementComponent;
    use crate::components::enforcement::EnforcementComponent::InternalImpl as EnforcementInternalImpl;
    use crate::components::erc20_base::ERC20BaseComponent;
    use crate::components::erc20_enforcement::ERC20EnforcementComponent;
    use crate::components::erc20_enforcement::ERC20EnforcementComponent::InternalImpl as ERC20EnforcementInternalImpl;
    use crate::components::pause::PauseComponent;
    use crate::components::pause::PauseComponent::InternalImpl as PauseInternalImpl;
    use crate::errors;
    use crate::interfaces::validation::{
        IERC3643ComplianceRead, IERC7551Compliance, IERC7943FungibleSendReceiveCheck,
    };

    #[storage]
    pub struct Storage {}

    #[embeddable_as(ERC7943SendReceiveImpl)]
    impl ERC7943SendReceive<
        TContractState,
        +HasComponent<TContractState>,
        +PauseComponent::HasComponent<TContractState>,
        impl Enforcement: EnforcementComponent::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IERC7943FungibleSendReceiveCheck<ComponentState<TContractState>> {
        fn can_send(self: @ComponentState<TContractState>, account: ContractAddress) -> bool {
            !get_dep_component!(self, Enforcement).is_address_frozen(account)
        }

        fn can_receive(self: @ComponentState<TContractState>, account: ContractAddress) -> bool {
            !get_dep_component!(self, Enforcement).is_address_frozen(account)
        }
    }

    /// CMTATBaseCore (Light): module checks only.
    #[embeddable_as(ComplianceReadCoreImpl)]
    impl ComplianceReadCore<
        TContractState,
        +HasComponent<TContractState>,
        +PauseComponent::HasComponent<TContractState>,
        +EnforcementComponent::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IERC3643ComplianceRead<ComponentState<TContractState>> {
        fn can_transfer(
            self: @ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
        ) -> bool {
            self.can_transfer_generic(Zero::zero(), from, to)
        }
    }

    #[embeddable_as(ComplianceReadFromCoreImpl)]
    impl ComplianceReadFromCore<
        TContractState,
        +HasComponent<TContractState>,
        +PauseComponent::HasComponent<TContractState>,
        +EnforcementComponent::HasComponent<TContractState>,
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
            self.can_transfer_generic(spender, from, to)
        }
    }

    /// Non-Light presets: active balance, then module checks.
    #[embeddable_as(ComplianceReadCommonImpl)]
    impl ComplianceReadCommon<
        TContractState,
        +HasComponent<TContractState>,
        +PauseComponent::HasComponent<TContractState>,
        +EnforcementComponent::HasComponent<TContractState>,
        +openzeppelin::token::erc20::ERC20Component::HasComponent<TContractState>,
        +openzeppelin::token::erc20::ERC20Component::ERC20HooksTrait<TContractState>,
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
            is_valid && self.can_transfer_generic(Zero::zero(), from, to)
        }
    }

    #[embeddable_as(ComplianceReadFromCommonImpl)]
    impl ComplianceReadFromCommon<
        TContractState,
        +HasComponent<TContractState>,
        +PauseComponent::HasComponent<TContractState>,
        +EnforcementComponent::HasComponent<TContractState>,
        +openzeppelin::token::erc20::ERC20Component::HasComponent<TContractState>,
        +openzeppelin::token::erc20::ERC20Component::ERC20HooksTrait<TContractState>,
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
            is_valid && self.can_transfer_generic(spender, from, to)
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl Pause: PauseComponent::HasComponent<TContractState>,
        impl Enforcement: EnforcementComponent::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Dispatches on the operation: `from == 0` is a mint, `to == 0` a burn,
        /// anything else a standard transfer.
        fn assert_can_transfer_generic(
            self: @ComponentState<TContractState>,
            spender: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
        ) {
            if from.is_zero() {
                self.assert_can_mint(to);
            } else if to.is_zero() {
                self.assert_can_burn(from);
            } else {
                self.assert_can_transfer_standard(spender, from, to);
            }
        }

        fn assert_can_transfer_standard(
            self: @ComponentState<TContractState>,
            spender: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
        ) {
            get_dep_component!(self, Pause).assert_not_paused();
            let enforcement = get_dep_component!(self, Enforcement);
            if enforcement.is_address_frozen(spender) {
                errors::cannot_send(spender);
            }
            if enforcement.is_address_frozen(from) {
                errors::cannot_send(from);
            }
            if enforcement.is_address_frozen(to) {
                errors::cannot_receive(to);
            }
        }

        fn assert_can_mint(self: @ComponentState<TContractState>, to: ContractAddress) {
            get_dep_component!(self, Pause).assert_not_deactivated();
            if get_dep_component!(self, Enforcement).is_address_frozen(to) {
                errors::cannot_receive(to);
            }
        }

        fn assert_can_burn(self: @ComponentState<TContractState>, from: ContractAddress) {
            get_dep_component!(self, Pause).assert_not_deactivated();
            if get_dep_component!(self, Enforcement).is_address_frozen(from) {
                errors::cannot_send(from);
            }
        }

        /// ValidationModuleAllowance: revoking (`value == 0`) is always allowed.
        fn assert_can_approve(
            self: @ComponentState<TContractState>,
            owner: ContractAddress,
            spender: ContractAddress,
            value: u256,
        ) {
            if value == 0 {
                return;
            }
            get_dep_component!(self, Pause).assert_not_paused();
            let enforcement = get_dep_component!(self, Enforcement);
            if enforcement.is_address_frozen(owner) {
                errors::cannot_send(owner);
            }
            if enforcement.is_address_frozen(spender) {
                errors::cannot_send(spender);
            }
        }

        /// Boolean form of `assert_can_transfer_generic`.
        fn can_transfer_generic(
            self: @ComponentState<TContractState>,
            spender: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
        ) -> bool {
            let pause = get_dep_component!(self, Pause);
            let enforcement = get_dep_component!(self, Enforcement);
            if from.is_zero() {
                !pause.is_deactivated() && !enforcement.is_address_frozen(to)
            } else if to.is_zero() {
                !pause.is_deactivated() && !enforcement.is_address_frozen(from)
            } else {
                !pause.is_paused()
                    && !enforcement.is_address_frozen(spender)
                    && !enforcement.is_address_frozen(from)
                    && !enforcement.is_address_frozen(to)
            }
        }
    }
}

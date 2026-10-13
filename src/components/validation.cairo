// SPDX-License-Identifier: MPL-2.0
// CMTAT ValidationModule: the pause / freeze / deactivation checks that gate
// transfers, mints, burns and approvals. Revert order follows CMTAT v3.3.0:
// - standard transfer: paused, then spender, from, to frozen (deactivation is not
//   checked: a deactivated contract is always paused);
// - mint: deactivated, then `to` frozen (pause does not block mint);
// - burn: deactivated, then `from` frozen (pause does not block burn);
// - approve: a zero value always passes; otherwise paused, then owner, spender frozen.

#[starknet::component]
pub mod ValidationComponent {
    use core::num::traits::Zero;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use crate::components::enforcement::EnforcementComponent;
    use crate::components::enforcement::EnforcementComponent::InternalImpl as EnforcementInternalImpl;
    use crate::components::pause::PauseComponent;
    use crate::components::pause::PauseComponent::InternalImpl as PauseInternalImpl;
    use crate::errors;

    #[storage]
    pub struct Storage {}

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
    }
}

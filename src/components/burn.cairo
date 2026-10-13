// SPDX-License-Identifier: MPL-2.0
// CMTAT ERC20BurnModule (burn, batch burn under BURNER_ROLE), the burn-from and
// self-burn functions of ERC20CrossChainModule (BURNER_FROM_ROLE, BURNER_SELF_ROLE;
// Standard and Snapshot presets only) and burn-and-mint. Every burn runs the
// preset's check chain with the operator as spender and `to == 0`.

#[starknet::component]
pub mod BurnComponent {
    use core::num::traits::Zero;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::ERC20Component;
    use openzeppelin::token::erc20::ERC20Component::InternalImpl as ERC20InternalImpl;
    use starknet::ContractAddress;
    use crate::components::access::CMTATAccessControlComponent;
    use crate::components::access::CMTATAccessControlComponent::InternalImpl as AccessInternalImpl;
    use crate::components::erc20_base::ERC20BaseComponent;
    use crate::components::erc20_base::ERC20BaseComponent::{
        CMTATHooksTrait, InternalImpl as ERC20BaseInternalImpl,
    };
    use crate::components::mint::MintComponent;
    use crate::components::mint::MintComponent::InternalImpl as MintInternalImpl;
    use crate::errors;
    use crate::interfaces::burn::{
        IBurnBatchERC20, IBurnFromERC20, IBurnMintERC20, IERC3643Burn, IERC5679Burn,
    };
    use crate::roles::{BURNER_FROM_ROLE, BURNER_ROLE, BURNER_SELF_ROLE, MINTER_ROLE};

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        Burn: Burn,
        BatchBurn: BatchBurn,
        BurnFrom: BurnFrom,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct Burn {
        #[key]
        pub burner: ContractAddress,
        #[key]
        pub account: ContractAddress,
        pub value: u256,
        pub data: Span<felt252>,
    }

    /// Emitted by batch burns instead of per-account `Burn` events.
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct BatchBurn {
        #[key]
        pub burner: ContractAddress,
        pub accounts: Span<ContractAddress>,
        pub values: Span<u256>,
        pub data: Span<felt252>,
    }

    /// Emitted by `burn_from` and `burn_self` instead of `Burn`.
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct BurnFrom {
        #[key]
        pub burner: ContractAddress,
        #[key]
        pub account: ContractAddress,
        #[key]
        pub spender: ContractAddress,
        pub value: u256,
    }

    #[embeddable_as(ERC3643BurnImpl)]
    impl ERC3643Burn<
        TContractState,
        +HasComponent<TContractState>,
        +ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        +ERC20BaseComponent::HasComponent<TContractState>,
        +CMTATHooksTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        impl Access: CMTATAccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IERC3643Burn<ComponentState<TContractState>> {
        fn burn(ref self: ComponentState<TContractState>, account: ContractAddress, value: u256) {
            get_dep_component!(@self, Access).assert_only_role(BURNER_ROLE);
            self._burn(account, value, array![].span());
        }

        fn batch_burn(
            ref self: ComponentState<TContractState>,
            accounts: Span<ContractAddress>,
            values: Span<u256>,
        ) {
            get_dep_component!(@self, Access).assert_only_role(BURNER_ROLE);
            self._batch_burn(accounts, values, array![].span());
        }
    }

    #[embeddable_as(ERC5679BurnImpl)]
    impl ERC5679Burn<
        TContractState,
        +HasComponent<TContractState>,
        +ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        +ERC20BaseComponent::HasComponent<TContractState>,
        +CMTATHooksTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        impl Access: CMTATAccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IERC5679Burn<ComponentState<TContractState>> {
        fn burn_with_data(
            ref self: ComponentState<TContractState>,
            account: ContractAddress,
            value: u256,
            data: Span<felt252>,
        ) {
            get_dep_component!(@self, Access).assert_only_role(BURNER_ROLE);
            self._burn(account, value, data);
        }
    }

    #[embeddable_as(BurnBatchImpl)]
    impl BurnBatchERC20<
        TContractState,
        +HasComponent<TContractState>,
        +ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        +ERC20BaseComponent::HasComponent<TContractState>,
        +CMTATHooksTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        impl Access: CMTATAccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IBurnBatchERC20<ComponentState<TContractState>> {
        fn batch_burn_with_data(
            ref self: ComponentState<TContractState>,
            accounts: Span<ContractAddress>,
            values: Span<u256>,
            data: Span<felt252>,
        ) {
            get_dep_component!(@self, Access).assert_only_role(BURNER_ROLE);
            self._batch_burn(accounts, values, data);
        }
    }

    #[embeddable_as(BurnFromImpl)]
    impl BurnFromERC20<
        TContractState,
        +HasComponent<TContractState>,
        +ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        impl ERC20Base: ERC20BaseComponent::HasComponent<TContractState>,
        +CMTATHooksTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        impl Access: CMTATAccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IBurnFromERC20<ComponentState<TContractState>> {
        /// Spends the caller's allowance (emitting `Spend`) before the check chain.
        fn burn_from(
            ref self: ComponentState<TContractState>, account: ContractAddress, value: u256,
        ) {
            get_dep_component!(@self, Access).assert_only_role(BURNER_FROM_ROLE);
            let sender = starknet::get_caller_address();
            let mut base = get_dep_component_mut!(ref self, ERC20Base);
            base.spend_allowance(account, sender, value);
            base.emit_spend(account, sender, value);
            self._burn_from_operator(sender, account, value);
        }

        fn burn_self(ref self: ComponentState<TContractState>, value: u256) {
            get_dep_component!(@self, Access).assert_only_role(BURNER_SELF_ROLE);
            let sender = starknet::get_caller_address();
            self._burn_from_operator(sender, sender, value);
        }
    }

    #[embeddable_as(BurnMintImpl)]
    impl BurnMintERC20<
        TContractState,
        +HasComponent<TContractState>,
        +ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        +ERC20BaseComponent::HasComponent<TContractState>,
        +CMTATHooksTrait<TContractState>,
        impl Mint: MintComponent::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        impl Access: CMTATAccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IBurnMintERC20<ComponentState<TContractState>> {
        /// Burns under BURNER_ROLE, then mints under MINTER_ROLE.
        fn burn_and_mint(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            amount_to_burn: u256,
            amount_to_mint: u256,
            data: Span<felt252>,
        ) {
            let access = get_dep_component!(@self, Access);
            access.assert_only_role(BURNER_ROLE);
            self._burn(from, amount_to_burn, data);
            access.assert_only_role(MINTER_ROLE);
            get_dep_component_mut!(ref self, Mint)._mint(to, amount_to_mint, data);
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC20: ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        impl ERC20Base: ERC20BaseComponent::HasComponent<TContractState>,
        impl Hooks: CMTATHooksTrait<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Burns after the check chain, without an access check, and emits `Burn`.
        fn _burn(
            ref self: ComponentState<TContractState>,
            account: ContractAddress,
            value: u256,
            data: Span<felt252>,
        ) {
            self._burn_unevented(account, value);
            self.emit(Burn { burner: starknet::get_caller_address(), account, value, data });
        }

        fn _batch_burn(
            ref self: ComponentState<TContractState>,
            accounts: Span<ContractAddress>,
            values: Span<u256>,
            data: Span<felt252>,
        ) {
            assert(accounts.len() > 0, errors::BURN_EMPTY_ACCOUNTS);
            assert(accounts.len() == values.len(), errors::BURN_ACCOUNTS_VALUES_LEN_MISMATCH);
            for i in 0..accounts.len() {
                self._burn_unevented(*accounts[i], *values[i]);
            }
            self.emit(BatchBurn { burner: starknet::get_caller_address(), accounts, values, data });
        }

        fn _burn_from_operator(
            ref self: ComponentState<TContractState>,
            sender: ContractAddress,
            account: ContractAddress,
            value: u256,
        ) {
            self._burn_unevented(account, value);
            self.emit(BurnFrom { burner: sender, account, spender: sender, value });
        }

        /// Burns after the check chain (operator as spender, to = 0). Emits only the
        /// ERC-20 `Transfer`.
        fn _burn_unevented(
            ref self: ComponentState<TContractState>, account: ContractAddress, value: u256,
        ) {
            let operator = starknet::get_caller_address();
            let mut base = get_dep_component_mut!(ref self, ERC20Base);
            Hooks::check_transferred(ref base, operator, account, Zero::zero(), value);
            get_dep_component_mut!(ref self, ERC20).burn(account, value);
        }
    }
}

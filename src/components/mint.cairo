// SPDX-License-Identifier: MPL-2.0
// CMTAT ERC20MintModule: mint, batch mint and minter batch transfer under
// MINTER_ROLE. Every leg runs the preset's check chain with the minter as spender.

#[starknet::component]
pub mod MintComponent {
    use core::num::traits::Zero;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::ERC20Component;
    use openzeppelin::token::erc20::ERC20Component::InternalImpl as ERC20InternalImpl;
    use starknet::ContractAddress;
    use crate::components::access::CMTATAccessControlComponent;
    use crate::components::access::CMTATAccessControlComponent::InternalImpl as AccessInternalImpl;
    use crate::components::erc20_base::ERC20BaseComponent;
    use crate::components::erc20_base::ERC20BaseComponent::CMTATHooksTrait;
    use crate::errors;
    use crate::interfaces::mint::{IERC3643BatchTransfer, IERC3643Mint, IERC5679Mint};
    use crate::roles::MINTER_ROLE;

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        Mint: Mint,
        BatchMint: BatchMint,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct Mint {
        #[key]
        pub minter: ContractAddress,
        #[key]
        pub account: ContractAddress,
        pub value: u256,
        pub data: Span<felt252>,
    }

    /// Emitted by `batch_mint` instead of per-account `Mint` events.
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct BatchMint {
        #[key]
        pub minter: ContractAddress,
        pub accounts: Span<ContractAddress>,
        pub values: Span<u256>,
    }

    #[embeddable_as(ERC3643MintImpl)]
    impl ERC3643Mint<
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
    > of IERC3643Mint<ComponentState<TContractState>> {
        fn mint(ref self: ComponentState<TContractState>, account: ContractAddress, value: u256) {
            get_dep_component!(@self, Access).assert_only_role(MINTER_ROLE);
            self._mint(account, value, array![].span());
        }

        fn batch_mint(
            ref self: ComponentState<TContractState>,
            accounts: Span<ContractAddress>,
            values: Span<u256>,
        ) {
            get_dep_component!(@self, Access).assert_only_role(MINTER_ROLE);
            assert(accounts.len() > 0, errors::MINT_EMPTY_ACCOUNTS);
            assert(accounts.len() == values.len(), errors::MINT_ACCOUNTS_VALUES_LEN_MISMATCH);
            for i in 0..accounts.len() {
                self._mint_unevented(*accounts[i], *values[i]);
            }
            self.emit(BatchMint { minter: starknet::get_caller_address(), accounts, values });
        }
    }

    #[embeddable_as(ERC3643BatchTransferImpl)]
    impl ERC3643BatchTransfer<
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
    > of IERC3643BatchTransfer<ComponentState<TContractState>> {
        /// Standard transfers from the minter: pause and freeze apply.
        fn batch_transfer(
            ref self: ComponentState<TContractState>,
            tos: Span<ContractAddress>,
            values: Span<u256>,
        ) -> bool {
            get_dep_component!(@self, Access).assert_only_role(MINTER_ROLE);
            assert(tos.len() > 0, errors::MINT_EMPTY_TOS);
            assert(tos.len() == values.len(), errors::MINT_TOS_VALUES_LEN_MISMATCH);
            let minter = starknet::get_caller_address();
            for i in 0..tos.len() {
                self._minter_transfer(minter, *tos[i], *values[i]);
            }
            true
        }
    }

    #[embeddable_as(ERC5679MintImpl)]
    impl ERC5679Mint<
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
    > of IERC5679Mint<ComponentState<TContractState>> {
        fn mint_with_data(
            ref self: ComponentState<TContractState>,
            account: ContractAddress,
            value: u256,
            data: Span<felt252>,
        ) {
            get_dep_component!(@self, Access).assert_only_role(MINTER_ROLE);
            self._mint(account, value, data);
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
        /// Mints after the check chain, without an access check, and emits `Mint`.
        fn _mint(
            ref self: ComponentState<TContractState>,
            account: ContractAddress,
            value: u256,
            data: Span<felt252>,
        ) {
            self._mint_unevented(account, value);
            self.emit(Mint { minter: starknet::get_caller_address(), account, value, data });
        }

        /// Mints after the check chain (operator as spender, from = 0). Emits only
        /// the ERC-20 `Transfer`.
        fn _mint_unevented(
            ref self: ComponentState<TContractState>, account: ContractAddress, value: u256,
        ) {
            let minter = starknet::get_caller_address();
            let mut base = get_dep_component_mut!(ref self, ERC20Base);
            Hooks::check_transferred(ref base, minter, Zero::zero(), account, value);
            get_dep_component_mut!(ref self, ERC20).mint(account, value);
        }

        fn _minter_transfer(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
        ) {
            let mut base = get_dep_component_mut!(ref self, ERC20Base);
            Hooks::check_transferred(ref base, from, from, to, value);
            get_dep_component_mut!(ref self, ERC20)._transfer(from, to, value);
        }
    }
}

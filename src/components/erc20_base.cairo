// SPDX-License-Identifier: MPL-2.0
// CMTAT ERC20BaseModule: the ERC-20 ABI over OpenZeppelin ERC-20 storage, with
// compliance checks run before balances move.
//
// Each preset supplies the check chain through `CMTATHooksTrait` (CMTAT's
// `_checkTransferred` / `_canAuthorizeAllowanceByModuleAndRevert`), so the
// spender is known; OpenZeppelin's `before_update` hook never sees it. Mint and
// burn components call `CMTATHooksTrait::check_transferred` with `from` or `to` zero.

#[starknet::component]
pub mod ERC20BaseComponent {
    use core::num::traits::{Bounded, Zero};
    use openzeppelin::interfaces::erc20::{IERC20, IERC20CamelOnly, IERC20Metadata};
    use openzeppelin::token::erc20::ERC20Component;
    use openzeppelin::token::erc20::ERC20Component::InternalImpl as ERC20InternalImpl;
    use starknet::ContractAddress;
    use starknet::storage::{
        StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use crate::interfaces::erc20_base::IERC20BatchBalance;

    #[storage]
    pub struct Storage {
        pub ERC20BaseModule_decimals: u8,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        Spend: Spend,
    }

    /// `spender` consumed `value` of the allowance granted by `account`.
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct Spend {
        #[key]
        pub account: ContractAddress,
        #[key]
        pub spender: ContractAddress,
        pub value: u256,
    }

    /// Compliance checks supplied by the preset.
    pub trait CMTATHooksTrait<TContractState> {
        /// CMTAT `_checkTransferred`: reverts unless `spender` may move `value` from
        /// `from` to `to`. `from == 0` is a mint, `to == 0` a burn.
        fn check_transferred(
            ref self: ComponentState<TContractState>,
            spender: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
        );

        /// CMTAT `_canAuthorizeAllowanceByModuleAndRevert`.
        fn check_approve(
            self: @ComponentState<TContractState>,
            owner: ContractAddress,
            spender: ContractAddress,
            value: u256,
        );
    }

    #[embeddable_as(ERC20Impl)]
    impl CMTATERC20<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC20: ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        impl Hooks: CMTATHooksTrait<TContractState>,
        +Drop<TContractState>,
    > of IERC20<ComponentState<TContractState>> {
        fn total_supply(self: @ComponentState<TContractState>) -> u256 {
            get_dep_component!(self, ERC20).ERC20_total_supply.read()
        }

        fn balance_of(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            get_dep_component!(self, ERC20).ERC20_balances.read(account)
        }

        fn allowance(
            self: @ComponentState<TContractState>, owner: ContractAddress, spender: ContractAddress,
        ) -> u256 {
            get_dep_component!(self, ERC20).ERC20_allowances.read((owner, spender))
        }

        /// Checks run with spender = 0, as in CMTAT.
        fn transfer(
            ref self: ComponentState<TContractState>, recipient: ContractAddress, amount: u256,
        ) -> bool {
            let from = starknet::get_caller_address();
            Hooks::check_transferred(ref self, Zero::zero(), from, recipient, amount);
            get_dep_component_mut!(ref self, ERC20)._transfer(from, recipient, amount);
            true
        }

        /// Checks run with the caller as spender. Emits `Spend` after the transfer.
        fn transfer_from(
            ref self: ComponentState<TContractState>,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) -> bool {
            let spender = starknet::get_caller_address();
            Hooks::check_transferred(ref self, spender, sender, recipient, amount);
            self.spend_allowance(sender, spender, amount);
            get_dep_component_mut!(ref self, ERC20)._transfer(sender, recipient, amount);
            self.emit(Spend { account: sender, spender, value: amount });
            true
        }

        fn approve(
            ref self: ComponentState<TContractState>, spender: ContractAddress, amount: u256,
        ) -> bool {
            let owner = starknet::get_caller_address();
            Hooks::check_approve(@self, owner, spender, amount);
            get_dep_component_mut!(ref self, ERC20)._approve(owner, spender, amount);
            true
        }
    }

    #[embeddable_as(ERC20CamelOnlyImpl)]
    impl ERC20CamelOnly<
        TContractState,
        +HasComponent<TContractState>,
        +ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        +CMTATHooksTrait<TContractState>,
        +Drop<TContractState>,
    > of IERC20CamelOnly<ComponentState<TContractState>> {
        fn totalSupply(self: @ComponentState<TContractState>) -> u256 {
            CMTATERC20::total_supply(self)
        }

        fn balanceOf(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            CMTATERC20::balance_of(self, account)
        }

        fn transferFrom(
            ref self: ComponentState<TContractState>,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) -> bool {
            CMTATERC20::transfer_from(ref self, sender, recipient, amount)
        }
    }

    /// Name and symbol live in OpenZeppelin ERC-20 storage; decimals are set at
    /// initialization.
    #[embeddable_as(ERC20MetadataImpl)]
    impl ERC20Metadata<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC20: ERC20Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IERC20Metadata<ComponentState<TContractState>> {
        fn name(self: @ComponentState<TContractState>) -> ByteArray {
            get_dep_component!(self, ERC20).ERC20_name.read()
        }

        fn symbol(self: @ComponentState<TContractState>) -> ByteArray {
            get_dep_component!(self, ERC20).ERC20_symbol.read()
        }

        fn decimals(self: @ComponentState<TContractState>) -> u8 {
            self.ERC20BaseModule_decimals.read()
        }
    }

    #[embeddable_as(ERC20BatchBalanceImpl)]
    impl ERC20BatchBalance<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC20: ERC20Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IERC20BatchBalance<ComponentState<TContractState>> {
        fn batch_balance_of(
            self: @ComponentState<TContractState>, addresses: Span<ContractAddress>,
        ) -> (Array<u256>, u256) {
            let erc20 = get_dep_component!(self, ERC20);
            let mut balances = array![];
            for address in addresses {
                balances.append(erc20.ERC20_balances.read(*address));
            }
            (balances, erc20.ERC20_total_supply.read())
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC20: ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(
            ref self: ComponentState<TContractState>,
            name: ByteArray,
            symbol: ByteArray,
            decimals: u8,
        ) {
            get_dep_component_mut!(ref self, ERC20).initializer(name, symbol);
            self.ERC20BaseModule_decimals.write(decimals);
        }

        /// Deducts `amount` from the allowance without emitting `Approval`
        /// (OpenZeppelin Solidity `_spendAllowance`). An infinite allowance is kept.
        fn spend_allowance(
            ref self: ComponentState<TContractState>,
            owner: ContractAddress,
            spender: ContractAddress,
            amount: u256,
        ) {
            let mut erc20 = get_dep_component_mut!(ref self, ERC20);
            let current = erc20.ERC20_allowances.read((owner, spender));
            if current != Bounded::MAX {
                assert(current >= amount, ERC20Component::Errors::INSUFFICIENT_ALLOWANCE);
                erc20.ERC20_allowances.write((owner, spender), current - amount);
            }
        }

        fn emit_spend(
            ref self: ComponentState<TContractState>,
            account: ContractAddress,
            spender: ContractAddress,
            value: u256,
        ) {
            self.emit(Spend { account, spender, value });
        }
    }
}

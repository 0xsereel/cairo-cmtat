// SPDX-License-Identifier: MPL-2.0
// Light CMTAT Implementation - Core CMTAT Framework Features

use starknet::ContractAddress;

#[starknet::contract]
mod LightCMTAT {
    use core::num::traits::{Zero};
    use openzeppelin::token::erc20::{ERC20Component, DefaultConfig};
    use openzeppelin::access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl AccessControlMixinImpl = AccessControlComponent::AccessControlMixinImpl<ContractState>;

    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    const MINTER_ROLE: felt252 = 'MINTER';
    const PAUSER_ROLE: felt252 = 'PAUSER';
    const ENFORCER_ROLE: felt252 = 'ENFORCER';

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        access_control: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        terms: ByteArray,
        information: ByteArray,
        token_id: ByteArray,
        // Core CMTAT compliance fields
        paused: bool,
        deactivated: bool,
        frozen_addresses: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        TermsSet: TermsSet,
        InformationSet: InformationSet,
        TokenIdSet: TokenIdSet,
        Paused: Paused,
        Unpaused: Unpaused,
        Deactivated: Deactivated,
        AddressFrozen: AddressFrozen,
        AddressUnfrozen: AddressUnfrozen,
        ForcedBurn: ForcedBurn,
        Mint: Mint,
        Burn: Burn,
    }

    #[derive(Drop, starknet::Event)]
    struct TermsSet {
        pub new_terms: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    struct InformationSet {
        pub new_information: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    struct TokenIdSet {
        pub new_token_id: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    struct Paused {
        pub account: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct Unpaused {
        pub account: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct Deactivated {
        pub account: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct AddressFrozen {
        #[key]
        pub account: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct AddressUnfrozen {
        #[key]
        pub account: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct ForcedBurn {
        #[key]
        pub from: ContractAddress,
        pub value: u256,
        pub admin: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct Mint {
        #[key]
        pub to: ContractAddress,
        pub value: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Burn {
        #[key]
        pub from: ContractAddress,
        pub value: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct ForcedTransfer {
        #[key]
        pub from: ContractAddress,
        #[key]
        pub to: ContractAddress,
        pub amount: u256,
        pub enforcer: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        initial_supply: u256,
        recipient: ContractAddress,
        terms: felt252
    ) {
        self.erc20.initializer(name, symbol);
        self.access_control.initializer();

        self.access_control._grant_role(DEFAULT_ADMIN_ROLE, admin);
        self.access_control._grant_role(MINTER_ROLE, admin);
        self.access_control._grant_role(PAUSER_ROLE, admin);
        self.access_control._grant_role(ENFORCER_ROLE, admin);

        self.terms.write("");
        self.information.write("");
        self.token_id.write("");
        self.paused.write(false);
        self.deactivated.write(false);

        if initial_supply > 0 {
            self.erc20.mint(recipient, initial_supply);
        }
    }

    #[abi(embed_v0)]
    impl LightCMTATImpl of super::ILightCMTAT<ContractState> {
        // ============ Information Functions ============
        fn terms(self: @ContractState) -> ByteArray {
            self.terms.read()
        }

        fn set_terms(ref self: ContractState, new_terms: ByteArray) {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.terms.write(new_terms.clone());
            self.emit(TermsSet { new_terms });
        }

        fn information(self: @ContractState) -> ByteArray {
            self.information.read()
        }

        fn set_information(ref self: ContractState, new_information: ByteArray) {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.information.write(new_information.clone());
            self.emit(InformationSet { new_information });
        }

        fn token_id(self: @ContractState) -> ByteArray {
            self.token_id.read()
        }

        fn set_token_id(ref self: ContractState, new_token_id: ByteArray) {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.token_id.write(new_token_id.clone());
            self.emit(TokenIdSet { new_token_id });
        }

        // ============ Batch Balance Query ============
        fn batch_balance_of(self: @ContractState, accounts: Span<ContractAddress>) -> Array<u256> {
            let mut balances = ArrayTrait::new();
            let mut i: u32 = 0;
            loop {
                if i >= accounts.len() {
                    break;
                }
                let account = *accounts.at(i);
                balances.append(self.erc20.balance_of(account));
                i += 1;
            };
            balances
        }

        // ============ Role Getters ============
        fn get_default_admin_role(self: @ContractState) -> felt252 {
            DEFAULT_ADMIN_ROLE
        }

        fn get_minter_role(self: @ContractState) -> felt252 {
            MINTER_ROLE
        }

        fn get_pauser_role(self: @ContractState) -> felt252 {
            PAUSER_ROLE
        }

        fn get_enforcer_role(self: @ContractState) -> felt252 {
            ENFORCER_ROLE
        }

        // ============ Version ============
        fn version(self: @ContractState) -> ByteArray {
            "0.1.0"
        }

        // ============ Minting Functions ============
        fn mint(ref self: ContractState, to: ContractAddress, value: u256) -> bool {
            self.access_control.assert_only_role(MINTER_ROLE);
            assert(!self.paused(), 'Contract is paused');
            self.erc20.mint(to, value);
            self.emit(Mint { to, value });
            true
        }

        fn batch_mint(ref self: ContractState, tos: Span<ContractAddress>, values: Span<u256>) -> bool {
            self.access_control.assert_only_role(MINTER_ROLE);
            assert(!self.paused(), 'Contract is paused');
            assert(tos.len() == values.len(), 'Arrays length mismatch');
            
            let mut i: u32 = 0;
            loop {
                if i >= tos.len() {
                    break;
                }
                let to = *tos.at(i);
                let value = *values.at(i);
                self.erc20.mint(to, value);
                self.emit(Mint { to, value });
                i += 1;
            };
            true
        }

        // ============ Burning Functions ============
        fn burn(ref self: ContractState, value: u256) -> bool {
            let from = get_caller_address();
            assert(!self.paused(), 'Contract is paused');
            self.erc20.burn(from, value);
            self.emit(Burn { from, value });
            true
        }

        fn burn_from(ref self: ContractState, from: ContractAddress, value: u256) -> bool {
            assert(!self.paused(), 'Contract is paused');
            let spender = get_caller_address();
            self.erc20._spend_allowance(from, spender, value);
            self.erc20.burn(from, value);
            self.emit(Burn { from, value });
            true
        }

        fn batch_burn(ref self: ContractState, accounts: Span<ContractAddress>, values: Span<u256>) -> bool {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            assert(!self.paused(), 'Contract is paused');
            assert(accounts.len() == values.len(), 'Arrays length mismatch');
            
            let mut i: u32 = 0;
            loop {
                if i >= accounts.len() {
                    break;
                }
                let from = *accounts.at(i);
                let value = *values.at(i);
                self.erc20.burn(from, value);
                self.emit(Burn { from, value });
                i += 1;
            };
            true
        }

        fn forced_burn(ref self: ContractState, from: ContractAddress, value: u256) -> bool {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.erc20.burn(from, value);
            self.emit(ForcedBurn { from, value, admin: get_caller_address() });
            true
        }

        fn burn_and_mint(ref self: ContractState, from: ContractAddress, to: ContractAddress, value: u256) -> bool {
            self.access_control.assert_only_role(MINTER_ROLE);
            assert(!self.paused(), 'Contract is paused');
            self.erc20.burn(from, value);
            self.emit(Burn { from, value });
            self.erc20.mint(to, value);
            self.emit(Mint { to, value });
            true
        }

        // ============ Pause Functions ============
        fn paused(self: @ContractState) -> bool {
            self.paused.read()
        }

        fn pause(ref self: ContractState) -> bool {
            self.access_control.assert_only_role(PAUSER_ROLE);
            self.paused.write(true);
            self.emit(Paused { account: get_caller_address() });
            true
        }

        fn unpause(ref self: ContractState) -> bool {
            self.access_control.assert_only_role(PAUSER_ROLE);
            self.paused.write(false);
            self.emit(Unpaused { account: get_caller_address() });
            true
        }

        fn deactivated(self: @ContractState) -> bool {
            self.deactivated.read()
        }

        fn deactivate_contract(ref self: ContractState) -> bool {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            assert(self.paused.read(), 'Must pause before deactivate');
            self.deactivated.write(true);
            self.emit(Deactivated { account: get_caller_address() });
            true
        }

        // ============ Freezing Functions ============
        fn set_address_frozen(ref self: ContractState, account: ContractAddress, is_frozen: bool) -> bool {
            self.access_control.assert_only_role(ENFORCER_ROLE);
            self.frozen_addresses.write(account, is_frozen);
            if is_frozen {
                self.emit(AddressFrozen { account });
            } else {
                self.emit(AddressUnfrozen { account });
            }
            true
        }

        fn batch_set_address_frozen(ref self: ContractState, accounts: Span<ContractAddress>, frozen: Span<bool>) -> bool {
            self.access_control.assert_only_role(ENFORCER_ROLE);
            assert(accounts.len() == frozen.len(), 'Arrays length mismatch');
            
            let mut i: u32 = 0;
            loop {
                if i >= accounts.len() {
                    break;
                }
                let account = *accounts.at(i);
                let is_frozen = *frozen.at(i);
                self.frozen_addresses.write(account, is_frozen);
                if is_frozen {
                    self.emit(AddressFrozen { account });
                } else {
                    self.emit(AddressUnfrozen { account });
                }
                i += 1;
            };
            true
        }

        fn is_frozen(self: @ContractState, account: ContractAddress) -> bool {
            self.frozen_addresses.read(account)
        }

        // ============ Utility Functions ============
        fn token_type(self: @ContractState) -> ByteArray {
            "Light CMTAT"
        }
    }

    // ERC20 Hooks for transfer restrictions
    impl ERC20HooksImpl of ERC20Component::ERC20HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            let contract_state = ERC20Component::HasComponent::get_contract(@self);
            let zero_address = Zero::zero();

            // Only check transfers (not mint/burn)
            if from != zero_address && recipient != zero_address {
                assert(!contract_state.paused.read(), 'Contract is paused');
                assert(!contract_state.is_frozen(from), 'Sender frozen');
                assert(!contract_state.is_frozen(recipient), 'Recipient frozen');
            }
        }

        fn after_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {}
    }
}

#[starknet::interface]
trait ILightCMTAT<TContractState> {
    // Information
    fn terms(self: @TContractState) -> ByteArray;
    fn set_terms(ref self: TContractState, new_terms: ByteArray);
    fn information(self: @TContractState) -> ByteArray;
    fn set_information(ref self: TContractState, new_information: ByteArray);
    fn token_id(self: @TContractState) -> ByteArray;
    fn set_token_id(ref self: TContractState, new_token_id: ByteArray);
    
    // Balance queries
    fn batch_balance_of(self: @TContractState, accounts: Span<ContractAddress>) -> Array<u256>;
    
    // Role getters
    fn get_default_admin_role(self: @TContractState) -> felt252;
    fn get_minter_role(self: @TContractState) -> felt252;
    fn get_pauser_role(self: @TContractState) -> felt252;
    fn get_enforcer_role(self: @TContractState) -> felt252;
    
    // Version
    fn version(self: @TContractState) -> ByteArray;
    
    // Minting
    fn mint(ref self: TContractState, to: ContractAddress, value: u256) -> bool;
    fn batch_mint(ref self: TContractState, tos: Span<ContractAddress>, values: Span<u256>) -> bool;
    
    // Burning
    fn burn(ref self: TContractState, value: u256) -> bool;
    fn burn_from(ref self: TContractState, from: ContractAddress, value: u256) -> bool;
    fn batch_burn(ref self: TContractState, accounts: Span<ContractAddress>, values: Span<u256>) -> bool;
    fn forced_burn(ref self: TContractState, from: ContractAddress, value: u256) -> bool;
    fn burn_and_mint(ref self: TContractState, from: ContractAddress, to: ContractAddress, value: u256) -> bool;
    
    // Pause
    fn paused(self: @TContractState) -> bool;
    fn pause(ref self: TContractState) -> bool;
    fn unpause(ref self: TContractState) -> bool;
    fn deactivated(self: @TContractState) -> bool;
    fn deactivate_contract(ref self: TContractState) -> bool;
    
    // Freezing
    fn set_address_frozen(ref self: TContractState, account: ContractAddress, is_frozen: bool) -> bool;
    fn batch_set_address_frozen(ref self: TContractState, accounts: Span<ContractAddress>, frozen: Span<bool>) -> bool;
    fn is_frozen(self: @TContractState, account: ContractAddress) -> bool;
    
    // Utility
    fn token_type(self: @TContractState) -> ByteArray;
}

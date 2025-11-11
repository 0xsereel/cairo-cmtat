// SPDX-License-Identifier: MPL-2.0
// Light CMTAT Implementation - Core CMTAT Framework Features

use starknet::ContractAddress;

#[starknet::contract]
mod LightCMTAT {
    use openzeppelin::token::erc20::{ERC20Component};
    use openzeppelin::access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::{ContractAddress, get_caller_address};

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
    const BURNER_ROLE: felt252 = 'BURNER';
    const ENFORCER_ROLE: felt252 = 'ENFORCER';

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        access_control: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        terms: felt252,
        // Core CMTAT compliance fields
        paused: bool,
        deactivated: bool,
        frozen_addresses: LegacyMap<ContractAddress, bool>,
        frozen_tokens: LegacyMap<ContractAddress, u256>,
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
        Paused: Paused,
        Unpaused: Unpaused,
        Deactivated: Deactivated,
        AddressFrozen: AddressFrozen,
        AddressUnfrozen: AddressUnfrozen,
        TokensFrozen: TokensFrozen,
        TokensUnfrozen: TokensUnfrozen,
        ForcedTransfer: ForcedTransfer,
    }

    #[derive(Drop, starknet::Event)]
    struct TermsSet {
        pub previous_terms: felt252,
        pub new_terms: felt252,
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
    struct TokensFrozen {
        #[key]
        pub account: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct TokensUnfrozen {
        #[key]
        pub account: ContractAddress,
        pub amount: u256,
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
        self.access_control._grant_role(BURNER_ROLE, admin);
        self.access_control._grant_role(ENFORCER_ROLE, admin);

        self.terms.write(terms);
        self.paused.write(false);
        self.deactivated.write(false);

        if initial_supply > 0 {
            self.erc20._mint(recipient, initial_supply);
        }
    }

    #[abi(embed_v0)]
    impl LightCMTATImpl of super::ILightCMTAT<ContractState> {
        fn terms(self: @ContractState) -> felt252 {
            self.terms.read()
        }

        fn set_terms(ref self: ContractState, new_terms: felt252) {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            let previous_terms = self.terms.read();
            self.terms.write(new_terms);
            self.emit(TermsSet { previous_terms, new_terms });
        }

        /// Mint tokens to a specified address
        /// 
        /// # Core CMTAT Restrictions:
        /// - Requires MINTER_ROLE permission
        /// - Contract must not be paused
        /// - Contract must not be deactivated
        /// - Target address must not be frozen
        /// 
        /// # Arguments:
        /// - `to`: Target address to receive tokens
        /// - `amount`: Amount of tokens to mint
        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
            self.access_control.assert_only_role(MINTER_ROLE);
            assert(!self.is_paused(), 'Contract is paused');
            assert(!self.is_deactivated(), 'Contract is deactivated');
            assert(!self.is_frozen(to), 'Address is frozen');
            self.erc20._mint(to, amount);
        }

        /// Burn tokens from a specified address
        /// 
        /// # Core CMTAT Restrictions:
        /// - Requires BURNER_ROLE permission
        /// - Contract must not be paused
        /// - Contract must not be deactivated
        /// - Must have sufficient active balance (unfrozen tokens)
        /// 
        /// # Arguments:
        /// - `from`: Address to burn tokens from
        /// - `amount`: Amount of tokens to burn
        fn burn(ref self: ContractState, from: ContractAddress, amount: u256) {
            self.access_control.assert_only_role(BURNER_ROLE);
            assert(!self.is_paused(), 'Contract is paused');
            assert(!self.is_deactivated(), 'Contract is deactivated');
            let active_balance = self.active_balance_of(from);
            assert(active_balance >= amount, 'Insufficient active balance');
            self.erc20._burn(from, amount);
        }

        // Pause/Unpause functionality (core CMTAT requirement)
        fn is_paused(self: @ContractState) -> bool {
            self.paused.read()
        }

        fn pause(ref self: ContractState) {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.paused.write(true);
            self.emit(Paused { account: get_caller_address() });
        }

        fn unpause(ref self: ContractState) {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.paused.write(false);
            self.emit(Unpaused { account: get_caller_address() });
        }

        // Deactivation functionality (core CMTAT requirement)
        fn is_deactivated(self: @ContractState) -> bool {
            self.deactivated.read()
        }

        fn deactivate_contract(ref self: ContractState) {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.deactivated.write(true);
            self.emit(Deactivated { account: get_caller_address() });
        }

        // Address freezing (core CMTAT requirement)
        fn freeze_address(ref self: ContractState, account: ContractAddress) {
            self.access_control.assert_only_role(ENFORCER_ROLE);
            self.frozen_addresses.write(account, true);
            self.emit(AddressFrozen { account });
        }

        fn unfreeze_address(ref self: ContractState, account: ContractAddress) {
            self.access_control.assert_only_role(ENFORCER_ROLE);
            self.frozen_addresses.write(account, false);
            self.emit(AddressUnfrozen { account });
        }

        fn is_frozen(self: @ContractState, account: ContractAddress) -> bool {
            self.frozen_addresses.read(account)
        }

        // Token freezing functionality (core CMTAT requirement)
        fn get_frozen_tokens(self: @ContractState, account: ContractAddress) -> u256 {
            self.frozen_tokens.read(account)
        }

        fn freeze_tokens(ref self: ContractState, account: ContractAddress, amount: u256) {
            self.access_control.assert_only_role(ENFORCER_ROLE);
            let current_frozen = self.frozen_tokens.read(account);
            self.frozen_tokens.write(account, current_frozen + amount);
            self.emit(TokensFrozen { account, amount });
        }

        fn unfreeze_tokens(ref self: ContractState, account: ContractAddress, amount: u256) {
            self.access_control.assert_only_role(ENFORCER_ROLE);
            let current_frozen = self.frozen_tokens.read(account);
            assert(current_frozen >= amount, 'Insufficient frozen tokens');
            self.frozen_tokens.write(account, current_frozen - amount);
            self.emit(TokensUnfrozen { account, amount });
        }

        fn active_balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            let total_balance = self.erc20.balance_of(account);
            let frozen_amount = self.frozen_tokens.read(account);
            if total_balance >= frozen_amount {
                total_balance - frozen_amount
            } else {
                0
            }
        }

        fn token_type(self: @ContractState) -> ByteArray {
            "Light CMTAT"
        }

        /// Force transfer tokens between addresses bypassing normal restrictions
        /// 
        /// This is an emergency administrative function that bypasses normal transfer
        /// restrictions including address freezes and token freezes. It should only
        /// be used for regulatory compliance, court orders, or emergency situations.
        /// 
        /// # Core CMTAT Requirements:
        /// - Requires DEFAULT_ADMIN_ROLE permission (highest authority)
        /// - Contract must not be deactivated
        /// - Automatically unfreezes necessary tokens for the transfer
        /// 
        /// # Arguments:
        /// - `from`: Source address to transfer tokens from
        /// - `to`: Target address to transfer tokens to
        /// - `amount`: Amount of tokens to force transfer
        /// 
        /// # Returns:
        /// - `bool`: true if transfer was successful
        fn forced_transfer(ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256) -> bool {
            // Only admin can perform forced transfers
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            
            // Cannot perform operations on deactivated contracts
            assert(!self.is_deactivated(), 'Contract is deactivated');
            
            // Validate sufficient total balance
            let total_balance = self.erc20.balance_of(from);
            assert(total_balance >= amount, 'Insufficient total balance');
            
            // If tokens are frozen, automatically unfreeze the required amount
            let frozen_amount = self.frozen_tokens.read(from);
            if frozen_amount > 0 {
                let active_balance = total_balance - frozen_amount;
                if active_balance < amount {
                    let unfreeze_needed = amount - active_balance;
                    let to_unfreeze = if unfreeze_needed > frozen_amount { frozen_amount } else { unfreeze_needed };
                    self.frozen_tokens.write(from, frozen_amount - to_unfreeze);
                    self.emit(TokensUnfrozen { account: from, amount: to_unfreeze });
                }
            }
            
            // Perform the transfer using internal ERC20 function (bypasses hooks)
            self.erc20._transfer(from, to, amount);
            
            // Emit forced transfer event for compliance tracking
            self.emit(ForcedTransfer { from, to, amount, enforcer: get_caller_address() });
            
            true
        }
    }

    // Internal transfer hook implementation for core CMTAT compliance
    impl ERC20HooksImpl of ERC20Component::ERC20HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            let contract_state = ERC20Component::HasComponent::get_contract(@self);

            // Core CMTAT compliance checks for transfers (not mint/burn)
            if from != starknet::contract_address_const::<0>() && recipient != starknet::contract_address_const::<0>() {
                // Check pause state
                assert(!contract_state.is_paused(), 'Contract is paused');
                
                // Check deactivation
                assert(!contract_state.is_deactivated(), 'Contract is deactivated');
                
                // Check if addresses are frozen
                assert(!contract_state.is_frozen(from), 'Sender address is frozen');
                assert(!contract_state.is_frozen(recipient), 'Recipient address is frozen');
                
                // Check active balance
                let active_balance = contract_state.active_balance_of(from);
                assert(active_balance >= amount, 'Insufficient active balance');
            }
        }

        fn after_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            // No post-transfer logic needed for Light CMTAT
        }
    }
}

#[starknet::interface]
trait ILightCMTAT<TContractState> {
    fn terms(self: @TContractState) -> felt252;
    fn set_terms(ref self: TContractState, new_terms: felt252);
    fn mint(ref self: TContractState, to: ContractAddress, amount: u256);
    fn burn(ref self: TContractState, from: ContractAddress, amount: u256);
    // Pause functionality
    fn is_paused(self: @TContractState) -> bool;
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    // Deactivation functionality
    fn is_deactivated(self: @TContractState) -> bool;
    fn deactivate_contract(ref self: TContractState);
    // Address freezing
    fn freeze_address(ref self: TContractState, account: ContractAddress);
    fn unfreeze_address(ref self: TContractState, account: ContractAddress);
    fn is_frozen(self: @TContractState, account: ContractAddress) -> bool;
    // Token freezing
    fn get_frozen_tokens(self: @TContractState, account: ContractAddress) -> u256;
    fn freeze_tokens(ref self: TContractState, account: ContractAddress, amount: u256);
    fn unfreeze_tokens(ref self: TContractState, account: ContractAddress, amount: u256);
    fn active_balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn token_type(self: @TContractState) -> ByteArray;
    // Force transfer
    fn forced_transfer(ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256) -> bool;
}

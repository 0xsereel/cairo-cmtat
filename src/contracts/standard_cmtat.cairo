// SPDX-License-Identifier: MPL-2.0
// Standard CMTAT Implementation - Full Features
//
// Supply Management Behavior:
// - Mint: Checks pause state, frozen addresses, requires MINTER_ROLE
// - Burn: Checks pause state, active balance, requires BURNER_ROLE
// 
// Missing from CMTAT v3.0.0 Solidity:
// - Rule engine integration for mint/burn operations  
// - Contract deactivation functionality
// - Batch operations (batchMint, batchBurn)
// - Cross-chain mint/burn operations

use starknet::ContractAddress;

#[starknet::contract]
mod StandardCMTAT {
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
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
    const SNAPSHOOTER_ROLE: felt252 = 'SNAPSHOOTER';

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        access_control: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        terms: felt252,
        information: ByteArray,
        frozen_addresses: LegacyMap<ContractAddress, bool>,
        frozen_tokens: LegacyMap<ContractAddress, u256>,
        paused: bool,
        deactivated: bool,
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
        Paused: Paused,
        Unpaused: Unpaused,
        Deactivated: Deactivated,
        AddressFrozen: AddressFrozen,
        AddressUnfrozen: AddressUnfrozen,
        TokensFrozen: TokensFrozen,
        TokensUnfrozen: TokensUnfrozen,
    }

    #[derive(Drop, starknet::Event)]
    struct TermsSet {
        pub previous_terms: felt252,
        pub new_terms: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct InformationSet {
        pub new_information: ByteArray,
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

    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        initial_supply: u256,
        recipient: ContractAddress,
        terms: felt252,
        information: ByteArray
    ) {
        self.erc20.initializer(name, symbol);
        self.access_control.initializer();

        self.access_control._grant_role(DEFAULT_ADMIN_ROLE, admin);
        self.access_control._grant_role(MINTER_ROLE, admin);
        self.access_control._grant_role(BURNER_ROLE, admin);
        self.access_control._grant_role(ENFORCER_ROLE, admin);
        self.access_control._grant_role(SNAPSHOOTER_ROLE, admin);

        self.terms.write(terms);
        self.information.write(information);
        self.paused.write(false);
        self.deactivated.write(false);

        if initial_supply > 0 {
            self.erc20._mint(recipient, initial_supply);
        }
    }

    #[abi(embed_v0)]
    impl StandardCMTATImpl of super::IStandardCMTAT<ContractState> {
        fn terms(self: @ContractState) -> felt252 {
            self.terms.read()
        }

        fn set_terms(ref self: ContractState, new_terms: felt252) {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            let previous_terms = self.terms.read();
            self.terms.write(new_terms);
            self.emit(TermsSet { previous_terms, new_terms });
        }

        fn information(self: @ContractState) -> ByteArray {
            self.information.read()
        }

        fn set_information(ref self: ContractState, new_information: ByteArray) {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.information.write(new_information.clone());
            self.emit(InformationSet { new_information });
        }

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
            assert(!self.is_deactivated(), 'Cannot unpause when deactivated');
            self.paused.write(false);
            self.emit(Unpaused { account: get_caller_address() });
        }

        // Deactivation functionality
        fn is_deactivated(self: @ContractState) -> bool {
            self.deactivated.read()
        }

        fn deactivate_contract(ref self: ContractState) {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            assert(self.is_paused(), 'Contract must be paused first');
            self.deactivated.write(true);
            self.emit(Deactivated { account: get_caller_address() });
        }

        /// Mint tokens to a specified address
        /// 
        /// # Restrictions:
        /// - Requires MINTER_ROLE permission
        /// - Contract must not be paused
        /// - Target address must not be frozen
        /// 
        /// # Arguments:
        /// - `to`: Target address to receive tokens
        /// - `amount`: Amount of tokens to mint
        /// 
        /// # Panics:
        /// - If caller doesn't have MINTER_ROLE
        /// - If contract is paused
        /// - If target address is frozen
        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
            self.access_control.assert_only_role(MINTER_ROLE);
            assert(!self.is_paused(), 'Contract is paused');
            assert(!self.is_frozen(to), 'Address is frozen');
            self.erc20._mint(to, amount);
        }

        /// Burn tokens from a specified address
        /// 
        /// # Restrictions:
        /// - Requires BURNER_ROLE permission  
        /// - Contract must not be paused
        /// - Must have sufficient active balance (unfrozen tokens)
        /// 
        /// # Arguments:
        /// - `from`: Address to burn tokens from
        /// - `amount`: Amount of tokens to burn
        /// 
        /// # Panics:
        /// - If caller doesn't have BURNER_ROLE
        /// - If contract is paused
        /// - If insufficient active balance (considering frozen tokens)
        /// 
        /// # Note:
        /// Unlike mint, this function does not check if the source address
        /// is frozen, but it does verify active balance which excludes frozen tokens.
        fn burn(ref self: ContractState, from: ContractAddress, amount: u256) {
            self.access_control.assert_only_role(BURNER_ROLE);
            assert(!self.is_paused(), 'Contract is paused');
            let active_balance = self.active_balance_of(from);
            assert(active_balance >= amount, 'Insufficient active balance');
            self.erc20._burn(from, amount);
        }

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

        fn get_frozen_tokens(self: @ContractState, account: ContractAddress) -> u256 {
            self.frozen_tokens.read(account)
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
            "Standard CMTAT"
        }

        /// Force transfer tokens from one address to another
        /// 
        /// # Administrative Override Function:
        /// - Requires DEFAULT_ADMIN_ROLE permission  
        /// - Can transfer from frozen addresses (bypasses freeze restrictions)
        /// - Automatically unfreezes partial tokens if needed
        /// - Contract must not be deactivated
        /// 
        /// # Arguments:
        /// - `from`: Source address to transfer tokens from
        /// - `to`: Target address to receive tokens
        /// - `amount`: Amount of tokens to transfer
        /// 
        /// # Returns:
        /// - `bool`: Always true if successful, reverts on failure
        /// 
        /// # Use Cases:
        /// - Regulatory compliance and court orders
        /// - Emergency corrections and error recovery
        /// - Moving tokens from frozen addresses
        fn forced_transfer(ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256) -> bool {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            assert(!self.is_deactivated(), 'Contract is deactivated');
            
            // Ensure sufficient balance exists (including frozen tokens)
            let total_balance = self.erc20.balance_of(from);
            assert(total_balance >= amount, 'Insufficient total balance');
            
            // If partial tokens are frozen, unfreeze them as needed
            let frozen_amount = self.frozen_tokens.read(from);
            if frozen_amount > 0 {
                let active_balance = if total_balance >= frozen_amount {
                    total_balance - frozen_amount
                } else {
                    0
                };
                
                // If we need to use frozen tokens, unfreeze the required amount
                if amount > active_balance && frozen_amount > 0 {
                    let unfreeze_amount = amount - active_balance;
                    let amount_to_unfreeze = if unfreeze_amount > frozen_amount {
                        frozen_amount
                    } else {
                        unfreeze_amount
                    };
                    
                    self.frozen_tokens.write(from, frozen_amount - amount_to_unfreeze);
                    self.emit(TokensUnfrozen { account: from, amount: amount_to_unfreeze });
                }
            }
            
            // Perform the forced transfer using internal ERC20 functions
            self.erc20._transfer(from, to, amount);
            
            true
        }
    }
}

#[starknet::interface]
trait IStandardCMTAT<TContractState> {
    fn terms(self: @TContractState) -> felt252;
    fn set_terms(ref self: TContractState, new_terms: felt252);
    fn information(self: @TContractState) -> ByteArray;
    fn set_information(ref self: TContractState, new_information: ByteArray);
    fn is_paused(self: @TContractState) -> bool;
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn is_deactivated(self: @TContractState) -> bool;
    fn deactivate_contract(ref self: TContractState);
    fn mint(ref self: TContractState, to: ContractAddress, amount: u256);
    fn burn(ref self: TContractState, from: ContractAddress, amount: u256);
    fn freeze_address(ref self: TContractState, account: ContractAddress);
    fn unfreeze_address(ref self: TContractState, account: ContractAddress);
    fn is_frozen(self: @TContractState, account: ContractAddress) -> bool;
    fn freeze_tokens(ref self: TContractState, account: ContractAddress, amount: u256);
    fn unfreeze_tokens(ref self: TContractState, account: ContractAddress, amount: u256);
    fn get_frozen_tokens(self: @TContractState, account: ContractAddress) -> u256;
    fn active_balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn forced_transfer(ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256) -> bool;
    fn token_type(self: @TContractState) -> ByteArray;
}

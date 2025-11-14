// SPDX-License-Identifier: MPL-2.0
// Allowlist CMTAT Implementation - Transfer restrictions via allowlist

use starknet::ContractAddress;

#[starknet::contract]
mod AllowlistCMTAT {
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin::access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{StorageMapReadAccess, StorageMapWriteAccess};

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
    const ALLOWLIST_ADMIN_ROLE: felt252 = 'ALLOWLIST_ADMIN';

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
        paused: bool,
        deactivated: bool,
        // Allowlist storage
        allowlist: LegacyMap<ContractAddress, bool>,
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
        AddressAddedToAllowlist: AddressAddedToAllowlist,
        AddressRemovedFromAllowlist: AddressRemovedFromAllowlist,
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
    struct AddressAddedToAllowlist {
        #[key]
        pub account: ContractAddress,
        pub added_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct AddressRemovedFromAllowlist {
        #[key]
        pub account: ContractAddress,
        pub removed_by: ContractAddress,
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
        self.access_control._grant_role(ALLOWLIST_ADMIN_ROLE, admin);

        self.terms.write(terms);
        self.information.write(information);
        self.paused.write(false);
        self.deactivated.write(false);

        // Add recipient to allowlist if initial supply is provided
        if initial_supply > 0 {
            self.allowlist.write(recipient, true);
            self.emit(AddressAddedToAllowlist { account: recipient, added_by: admin });
            self.erc20._mint(recipient, initial_supply);
        }
    }

    #[abi(embed_v0)]
    impl AllowlistCMTATImpl of super::IAllowlistCMTAT<ContractState> {
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
        /// - Target address must be on the allowlist
        /// 
        /// # Arguments:
        /// - `to`: Target address to receive tokens
        /// - `amount`: Amount of tokens to mint
        /// 
        /// # Panics:
        /// - If caller doesn't have MINTER_ROLE
        /// - If contract is paused
        /// - If target address is not on allowlist
        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
            self.access_control.assert_only_role(MINTER_ROLE);
            assert(!self.is_paused(), 'Contract is paused');
            assert(self.is_allowed(to), 'Address not on allowlist');
            self.erc20._mint(to, amount);
        }

        /// Burn tokens from a specified address
        /// 
        /// # Restrictions:
        /// - Requires BURNER_ROLE permission  
        /// - Contract must not be paused
        /// 
        /// # Arguments:
        /// - `from`: Address to burn tokens from
        /// - `amount`: Amount of tokens to burn
        /// 
        /// # Panics:
        /// - If caller doesn't have BURNER_ROLE
        /// - If contract is paused
        /// - If insufficient balance
        fn burn(ref self: ContractState, from: ContractAddress, amount: u256) {
            self.access_control.assert_only_role(BURNER_ROLE);
            assert(!self.is_paused(), 'Contract is paused');
            self.erc20._burn(from, amount);
        }

        /// Transfer tokens with allowlist validation
        /// 
        /// # Restrictions:
        /// - Contract must not be paused
        /// - Both sender and recipient must be on allowlist
        /// 
        /// # Arguments:
        /// - `recipient`: Address to receive tokens
        /// - `amount`: Amount of tokens to transfer
        /// 
        /// # Returns:
        /// - `bool`: true if successful
        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            assert(!self.is_paused(), 'Contract is paused');
            let sender = get_caller_address();
            assert(self.is_allowed(sender), 'Sender not on allowlist');
            assert(self.is_allowed(recipient), 'Recipient not on allowlist');
            self.erc20._transfer(sender, recipient, amount);
            true
        }

        /// Transfer tokens from an address with allowlist validation
        /// 
        /// # Restrictions:
        /// - Contract must not be paused
        /// - Both sender and recipient must be on allowlist
        /// - Caller must have sufficient allowance
        /// 
        /// # Arguments:
        /// - `sender`: Address to transfer tokens from
        /// - `recipient`: Address to receive tokens
        /// - `amount`: Amount of tokens to transfer
        /// 
        /// # Returns:
        /// - `bool`: true if successful
        fn transfer_from(
            ref self: ContractState, 
            sender: ContractAddress, 
            recipient: ContractAddress, 
            amount: u256
        ) -> bool {
            assert(!self.is_paused(), 'Contract is paused');
            assert(self.is_allowed(sender), 'Sender not on allowlist');
            assert(self.is_allowed(recipient), 'Recipient not on allowlist');
            
            let caller = get_caller_address();
            self.erc20._spend_allowance(sender, caller, amount);
            self.erc20._transfer(sender, recipient, amount);
            true
        }

        /// Force transfer tokens from one address to another
        /// 
        /// # Administrative Override Function:
        /// - Requires DEFAULT_ADMIN_ROLE permission  
        /// - Can transfer even if addresses are not on allowlist
        /// - Contract must not be deactivated
        /// 
        /// # Arguments:
        /// - `from`: Source address to transfer tokens from
        /// - `to`: Target address to receive tokens
        /// - `amount`: Amount of tokens to transfer
        /// 
        /// # Returns:
        /// - `bool`: Always true if successful, reverts on failure
        fn forced_transfer(
            ref self: ContractState, 
            from: ContractAddress, 
            to: ContractAddress, 
            amount: u256
        ) -> bool {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            assert(!self.is_deactivated(), 'Contract is deactivated');
            
            self.erc20._transfer(from, to, amount);
            true
        }

        // Allowlist management functions
        
        /// Check if an address is on the allowlist
        /// 
        /// # Arguments:
        /// - `account`: Address to check
        /// 
        /// # Returns:
        /// - `bool`: true if address is on allowlist
        fn is_allowed(self: @ContractState, account: ContractAddress) -> bool {
            self.allowlist.read(account)
        }

        /// Add an address to the allowlist
        /// 
        /// # Restrictions:
        /// - Requires ALLOWLIST_ADMIN_ROLE permission
        /// 
        /// # Arguments:
        /// - `account`: Address to add to allowlist
        fn add_to_allowlist(ref self: ContractState, account: ContractAddress) {
            self.access_control.assert_only_role(ALLOWLIST_ADMIN_ROLE);
            self.allowlist.write(account, true);
            let caller = get_caller_address();
            self.emit(AddressAddedToAllowlist { account, added_by: caller });
        }

        /// Remove an address from the allowlist
        /// 
        /// # Restrictions:
        /// - Requires ALLOWLIST_ADMIN_ROLE permission
        /// 
        /// # Arguments:
        /// - `account`: Address to remove from allowlist
        fn remove_from_allowlist(ref self: ContractState, account: ContractAddress) {
            self.access_control.assert_only_role(ALLOWLIST_ADMIN_ROLE);
            self.allowlist.write(account, false);
            let caller = get_caller_address();
            self.emit(AddressRemovedFromAllowlist { account, removed_by: caller });
        }

        /// Add multiple addresses to the allowlist in batch
        /// 
        /// # Restrictions:
        /// - Requires ALLOWLIST_ADMIN_ROLE permission
        /// 
        /// # Arguments:
        /// - `accounts`: Array of addresses to add to allowlist
        fn batch_add_to_allowlist(ref self: ContractState, accounts: Span<ContractAddress>) {
            self.access_control.assert_only_role(ALLOWLIST_ADMIN_ROLE);
            let caller = get_caller_address();
            let mut i: u32 = 0;
            loop {
                if i >= accounts.len() {
                    break;
                }
                let account = *accounts.at(i);
                self.allowlist.write(account, true);
                self.emit(AddressAddedToAllowlist { account, added_by: caller });
                i += 1;
            }
        }

        /// Remove multiple addresses from the allowlist in batch
        /// 
        /// # Restrictions:
        /// - Requires ALLOWLIST_ADMIN_ROLE permission
        /// 
        /// # Arguments:
        /// - `accounts`: Array of addresses to remove from allowlist
        fn batch_remove_from_allowlist(ref self: ContractState, accounts: Span<ContractAddress>) {
            self.access_control.assert_only_role(ALLOWLIST_ADMIN_ROLE);
            let caller = get_caller_address();
            let mut i: u32 = 0;
            loop {
                if i >= accounts.len() {
                    break;
                }
                let account = *accounts.at(i);
                self.allowlist.write(account, false);
                self.emit(AddressRemovedFromAllowlist { account, removed_by: caller });
                i += 1;
            }
        }

        fn token_type(self: @ContractState) -> ByteArray {
            "Allowlist CMTAT"
        }
    }
}

#[starknet::interface]
trait IAllowlistCMTAT<TContractState> {
    // Basic information
    fn terms(self: @TContractState) -> felt252;
    fn set_terms(ref self: TContractState, new_terms: felt252);
    fn information(self: @TContractState) -> ByteArray;
    fn set_information(ref self: TContractState, new_information: ByteArray);
    
    // Pause/deactivate functionality
    fn is_paused(self: @TContractState) -> bool;
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn is_deactivated(self: @TContractState) -> bool;
    fn deactivate_contract(ref self: TContractState);
    
    // Token operations
    fn mint(ref self: TContractState, to: ContractAddress, amount: u256);
    fn burn(ref self: TContractState, from: ContractAddress, amount: u256);
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn forced_transfer(ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256) -> bool;
    
    // Allowlist management
    fn is_allowed(self: @TContractState, account: ContractAddress) -> bool;
    fn add_to_allowlist(ref self: TContractState, account: ContractAddress);
    fn remove_from_allowlist(ref self: TContractState, account: ContractAddress);
    fn batch_add_to_allowlist(ref self: TContractState, accounts: Span<ContractAddress>);
    fn batch_remove_from_allowlist(ref self: TContractState, accounts: Span<ContractAddress>);
    
    fn token_type(self: @TContractState) -> ByteArray;
}

// SPDX-License-Identifier: MPL-2.0
// Simplified Rule Engine for CMTAT Cairo

use starknet::ContractAddress;

/// Rule Engine Interface - Controls transfer restrictions
#[starknet::interface]
pub trait IRuleEngine<TContractState> {
    /// Detects transfer restriction code (ERC-1404 compatible)
    /// Returns 0 if no restriction, non-zero code otherwise
    fn detect_transfer_restriction(
        self: @TContractState,
        from: ContractAddress,
        to: ContractAddress,
        amount: u256
    ) -> u8;
    
    /// Returns human-readable message for restriction code
    fn message_for_restriction_code(self: @TContractState, restriction_code: u8) -> ByteArray;
    
    /// Called after successful transfer to update engine state
    fn on_transfer_executed(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        amount: u256
    );
    
    /// Check if address is allowed to hold tokens
    fn is_address_valid(self: @TContractState, addr: ContractAddress) -> bool;
}

/// Simple Whitelist Rule Engine Implementation
#[starknet::contract]
mod WhitelistRuleEngine {
    use super::IRuleEngine;
    use openzeppelin::access::ownable::OwnableComponent;
    use starknet::{ContractAddress, get_caller_address};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        whitelisted: LegacyMap<ContractAddress, bool>,
        max_balance: u256,
        token_contract: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        AddressWhitelisted: AddressWhitelisted,
        AddressRemoved: AddressRemoved,
        MaxBalanceSet: MaxBalanceSet,
    }

    #[derive(Drop, starknet::Event)]
    struct AddressWhitelisted {
        #[key]
        pub address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct AddressRemoved {
        #[key]
        pub address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct MaxBalanceSet {
        pub max_balance: u256,
    }

    mod Errors {
        pub const NOT_AUTHORIZED: felt252 = 'Rule: caller not authorized';
        pub const ZERO_ADDRESS: felt252 = 'Rule: zero address';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        token_contract: ContractAddress,
        max_balance: u256
    ) {
        self.ownable.initializer(owner);
        self.token_contract.write(token_contract);
        self.max_balance.write(max_balance);
    }

    #[abi(embed_v0)]
    impl RuleEngineImpl of IRuleEngine<ContractState> {
        fn detect_transfer_restriction(
            self: @ContractState,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) -> u8 {
            let zero_address = starknet::contract_address_const::<0>();
            
            // Allow minting (from zero address)
            if from == zero_address {
                if !self.is_address_valid(to) {
                    return 1; // Recipient not whitelisted
                }
                return 0;
            }
            
            // Allow burning (to zero address)
            if to == zero_address {
                return 0;
            }
            
            // Check sender whitelisted
            if !self.is_address_valid(from) {
                return 2; // Sender not whitelisted
            }
            
            // Check recipient whitelisted
            if !self.is_address_valid(to) {
                return 1; // Recipient not whitelisted
            }
            
            // Check max balance (simplified - would need to query token balance in practice)
            let max_bal = self.max_balance.read();
            if max_bal > 0 && amount > max_bal {
                return 3; // Exceeds max balance
            }
            
            0 // No restriction
        }

        fn message_for_restriction_code(self: @ContractState, restriction_code: u8) -> ByteArray {
            if restriction_code == 0 {
                "No restriction"
            } else if restriction_code == 1 {
                "Recipient not whitelisted"
            } else if restriction_code == 2 {
                "Sender not whitelisted"
            } else if restriction_code == 3 {
                "Exceeds maximum balance"
            } else {
                "Unknown restriction"
            }
        }

        fn on_transfer_executed(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) {
            // Can be used to update internal state, track volumes, etc.
            // This simple implementation doesn't need state updates
        }

        fn is_address_valid(self: @ContractState, addr: ContractAddress) -> bool {
            self.whitelisted.read(addr)
        }
    }

    #[abi(embed_v0)]
    impl WhitelistManagement of super::IWhitelistManagement<ContractState> {
        fn add_to_whitelist(ref self: ContractState, address: ContractAddress) {
            self.ownable.assert_only_owner();
            let zero_address = starknet::contract_address_const::<0>();
            assert(address != zero_address, Errors::ZERO_ADDRESS);
            
            self.whitelisted.write(address, true);
            self.emit(AddressWhitelisted { address });
        }

        fn remove_from_whitelist(ref self: ContractState, address: ContractAddress) {
            self.ownable.assert_only_owner();
            
            self.whitelisted.write(address, false);
            self.emit(AddressRemoved { address });
        }

        fn batch_add_to_whitelist(ref self: ContractState, addresses: Array<ContractAddress>) {
            self.ownable.assert_only_owner();
            
            let zero_address = starknet::contract_address_const::<0>();
            let mut i = 0;
            loop {
                if i >= addresses.len() {
                    break;
                }
                let addr = *addresses.at(i);
                if addr != zero_address {
                    self.whitelisted.write(addr, true);
                    self.emit(AddressWhitelisted { address: addr });
                }
                i += 1;
            }
        }

        fn set_max_balance(ref self: ContractState, max_balance: u256) {
            self.ownable.assert_only_owner();
            self.max_balance.write(max_balance);
            self.emit(MaxBalanceSet { max_balance });
        }

        fn get_max_balance(self: @ContractState) -> u256 {
            self.max_balance.read()
        }
    }
}

#[starknet::interface]
pub trait IWhitelistManagement<TContractState> {
    fn add_to_whitelist(ref self: TContractState, address: ContractAddress);
    fn remove_from_whitelist(ref self: TContractState, address: ContractAddress);
    fn batch_add_to_whitelist(ref self: TContractState, addresses: Array<ContractAddress>);
    fn set_max_balance(ref self: TContractState, max_balance: u256);
    fn get_max_balance(self: @TContractState) -> u256;
}

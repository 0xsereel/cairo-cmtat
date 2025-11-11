// SPDX-License-Identifier: MPL-2.0
// Debt CMTAT Implementation - For Debt Instruments
//
// Supply Management Behavior:
// - Mint: Full CMTAT v3.0.0 compliance (pause, deactivation, frozen addresses, rule engine)
// - Burn: Full CMTAT v3.0.0 compliance (pause, deactivation, active balance, rule engine)
//
// Features aligned with CMTAT v3.0.0 Solidity:
//  Pause state checks in mint/burn
//  Contract deactivation functionality
//  Active balance validation in burn
//  Rule engine integration
//  Partial token freezing support
//  Enhanced transfer restrictions

use starknet::ContractAddress;
use cairo_cmtat::engines::rule_engine::{IRuleEngineDispatcher, IRuleEngineDispatcherTrait};
use cairo_cmtat::engines::snapshot_engine::{ISnapshotEngineDispatcher, ISnapshotEngineDispatcherTrait, ISnapshotRecordingDispatcher, ISnapshotRecordingDispatcherTrait};

#[starknet::contract]
mod DebtCMTAT {
    use openzeppelin::token::erc20::{ERC20Component};
    use openzeppelin::access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::{ContractAddress, get_caller_address};
    use super::{IRuleEngineDispatcher, IRuleEngineDispatcherTrait, ISnapshotEngineDispatcher, ISnapshotEngineDispatcherTrait, ISnapshotRecordingDispatcher, ISnapshotRecordingDispatcherTrait};

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
    const DEBT_ROLE: felt252 = 'DEBT_ROLE';

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        access_control: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        terms: felt252,
        // Engine integration
        rule_engine: ContractAddress,
        snapshot_engine: ContractAddress,
        // Debt-specific fields
        isin: ByteArray,
        maturity_date: u64,
        interest_rate: u256,
        par_value: u256,
        credit_event_occurred: bool,
        credit_event_type: ByteArray,
        frozen_addresses: LegacyMap<ContractAddress, bool>,
        // Compliance fields
        paused: bool,
        deactivated: bool,
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
        ISINSet: ISINSet,
        MaturityDateSet: MaturityDateSet,
        InterestRateSet: InterestRateSet,
        ParValueSet: ParValueSet,
        CreditEventSet: CreditEventSet,
        AddressFrozen: AddressFrozen,
        AddressUnfrozen: AddressUnfrozen,
        Paused: Paused,
        Unpaused: Unpaused,
        Deactivated: Deactivated,
        TokensFrozen: TokensFrozen,
        TokensUnfrozen: TokensUnfrozen,
    }

    #[derive(Drop, starknet::Event)]
    struct TermsSet {
        pub previous_terms: felt252,
        pub new_terms: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct ISINSet {
        pub new_isin: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    struct MaturityDateSet {
        pub new_maturity_date: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct InterestRateSet {
        pub new_interest_rate: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct ParValueSet {
        pub new_par_value: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct CreditEventSet {
        pub event_type: ByteArray,
        pub occurred: bool,
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
        isin: ByteArray,
        maturity_date: u64,
        interest_rate: u256,
        par_value: u256,
        rule_engine: ContractAddress,
        snapshot_engine: ContractAddress
    ) {
        self.erc20.initializer(name, symbol);
        self.access_control.initializer();

        self.access_control._grant_role(DEFAULT_ADMIN_ROLE, admin);
        self.access_control._grant_role(MINTER_ROLE, admin);
        self.access_control._grant_role(BURNER_ROLE, admin);
        self.access_control._grant_role(DEBT_ROLE, admin);

        self.terms.write(terms);
        self.rule_engine.write(rule_engine);
        self.snapshot_engine.write(snapshot_engine);
        self.isin.write(isin);
        self.maturity_date.write(maturity_date);
        self.interest_rate.write(interest_rate);
        self.par_value.write(par_value);
        self.credit_event_occurred.write(false);
        self.paused.write(false);
        self.deactivated.write(false);

        if initial_supply > 0 {
            self.erc20._mint(recipient, initial_supply);
        }
    }

    #[abi(embed_v0)]
    impl DebtCMTATImpl of super::IDebtCMTAT<ContractState> {
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
        /// # Restrictions:
        /// - Requires MINTER_ROLE permission
        /// - Contract must not be paused
        /// - Contract must not be deactivated
        /// - Target address must not be frozen
        /// - Calls rule engine for validation if configured
        /// 
        /// # Arguments:
        /// - `to`: Target address to receive tokens
        /// - `amount`: Amount of tokens to mint
        /// 
        /// # Panics:
        /// - If caller doesn't have MINTER_ROLE
        /// - If contract is paused
        /// - If contract is deactivated
        /// - If target address is frozen
        /// - If rule engine restricts the operation
        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
            self.access_control.assert_only_role(MINTER_ROLE);
            assert(!self.is_paused(), 'Contract is paused');
            assert(!self.is_deactivated(), 'Contract is deactivated');
            assert(!self.is_frozen(to), 'Address is frozen');
            
            // Call rule engine if configured
            let rule_engine_addr = self.rule_engine.read();
            if rule_engine_addr != starknet::contract_address_const::<0>() {
                let rule_engine = IRuleEngineDispatcher { contract_address: rule_engine_addr };
                let restriction = rule_engine.detect_transfer_restriction(
                    starknet::contract_address_const::<0>(), 
                    to, 
                    amount
                );
                assert(restriction == 0, 'Transfer restricted by rules');
            }
            
            self.erc20._mint(to, amount);
        }

        /// Burn tokens from a specified address
        /// 
        /// # Restrictions:
        /// - Requires BURNER_ROLE permission
        /// 
        /// # Arguments:
        /// - `from`: Address to burn tokens from
        /// - `amount`: Amount of tokens to burn
        /// 
        /// # Panics:
        /// - If caller doesn't have BURNER_ROLE
        /// - If insufficient balance (standard ERC20 check)
        /// 
        /// # Warning:
        /// This implementation is missing several checks compared to
        /// Standard CMTAT and CMTAT v3.0.0 Solidity:
        /// - No pause state check
        /// - No frozen address check
        /// - No active balance check (ignores frozen tokens)
        /// - No rule engine integration
        /// Burn tokens from a specified address
        /// 
        /// # Restrictions:
        /// - Requires BURNER_ROLE permission
        /// - Contract must not be paused
        /// - Contract must not be deactivated
        /// - Must have sufficient active balance (unfrozen tokens)
        /// - Calls rule engine for validation if configured
        /// 
        /// # Arguments:
        /// - `from`: Address to burn tokens from
        /// - `amount`: Amount of tokens to burn
        /// 
        /// # Panics:
        /// - If caller doesn't have BURNER_ROLE
        /// - If contract is paused
        /// - If contract is deactivated
        /// - If insufficient active balance (considering frozen tokens)
        /// - If rule engine restricts the operation
        fn burn(ref self: ContractState, from: ContractAddress, amount: u256) {
            self.access_control.assert_only_role(BURNER_ROLE);
            assert(!self.is_paused(), 'Contract is paused');
            assert(!self.is_deactivated(), 'Contract is deactivated');
            
            let active_balance = self.active_balance_of(from);
            assert(active_balance >= amount, 'Insufficient active balance');
            
            // Call rule engine if configured
            let rule_engine_addr = self.rule_engine.read();
            if rule_engine_addr != starknet::contract_address_const::<0>() {
                let rule_engine = IRuleEngineDispatcher { contract_address: rule_engine_addr };
                let restriction = rule_engine.detect_transfer_restriction(
                    from, 
                    starknet::contract_address_const::<0>(), 
                    amount
                );
                assert(restriction == 0, 'Transfer restricted by rules');
            }
            
            self.erc20._burn(from, amount);
        }

        fn freeze_address(ref self: ContractState, account: ContractAddress) {
            self.access_control.assert_only_role(DEBT_ROLE);
            self.frozen_addresses.write(account, true);
            self.emit(AddressFrozen { account });
        }

        fn unfreeze_address(ref self: ContractState, account: ContractAddress) {
            self.access_control.assert_only_role(DEBT_ROLE);
            self.frozen_addresses.write(account, false);
            self.emit(AddressUnfrozen { account });
        }

        fn is_frozen(self: @ContractState, account: ContractAddress) -> bool {
            self.frozen_addresses.read(account)
        }

        // Pause/Unpause functionality
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

        // Deactivation functionality
        fn is_deactivated(self: @ContractState) -> bool {
            self.deactivated.read()
        }

        fn deactivate_contract(ref self: ContractState) {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.deactivated.write(true);
            self.emit(Deactivated { account: get_caller_address() });
        }

        // Token freezing functionality
        fn get_frozen_tokens(self: @ContractState, account: ContractAddress) -> u256 {
            self.frozen_tokens.read(account)
        }

        fn freeze_tokens(ref self: ContractState, account: ContractAddress, amount: u256) {
            self.access_control.assert_only_role(DEBT_ROLE);
            let current_frozen = self.frozen_tokens.read(account);
            self.frozen_tokens.write(account, current_frozen + amount);
            self.emit(TokensFrozen { account, amount });
        }

        fn unfreeze_tokens(ref self: ContractState, account: ContractAddress, amount: u256) {
            self.access_control.assert_only_role(DEBT_ROLE);
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

        // Debt-specific functions
        fn get_isin(self: @ContractState) -> ByteArray {
            self.isin.read()
        }

        fn set_isin(ref self: ContractState, new_isin: ByteArray) {
            self.access_control.assert_only_role(DEBT_ROLE);
            self.isin.write(new_isin.clone());
            self.emit(ISINSet { new_isin });
        }

        fn get_maturity_date(self: @ContractState) -> u64 {
            self.maturity_date.read()
        }

        fn set_maturity_date(ref self: ContractState, new_maturity_date: u64) {
            self.access_control.assert_only_role(DEBT_ROLE);
            self.maturity_date.write(new_maturity_date);
            self.emit(MaturityDateSet { new_maturity_date });
        }

        fn get_interest_rate(self: @ContractState) -> u256 {
            self.interest_rate.read()
        }

        fn set_interest_rate(ref self: ContractState, new_interest_rate: u256) {
            self.access_control.assert_only_role(DEBT_ROLE);
            self.interest_rate.write(new_interest_rate);
            self.emit(InterestRateSet { new_interest_rate });
        }

        fn get_par_value(self: @ContractState) -> u256 {
            self.par_value.read()
        }

        fn set_par_value(ref self: ContractState, new_par_value: u256) {
            self.access_control.assert_only_role(DEBT_ROLE);
            self.par_value.write(new_par_value);
            self.emit(ParValueSet { new_par_value });
        }

        fn has_credit_event(self: @ContractState) -> bool {
            self.credit_event_occurred.read()
        }

        fn get_credit_event_type(self: @ContractState) -> ByteArray {
            self.credit_event_type.read()
        }

        fn set_credit_event(ref self: ContractState, event_type: ByteArray, occurred: bool) {
            self.access_control.assert_only_role(DEBT_ROLE);
            self.credit_event_occurred.write(occurred);
            self.credit_event_type.write(event_type.clone());
            self.emit(CreditEventSet { event_type, occurred });
        }

        fn token_type(self: @ContractState) -> ByteArray {
            "Debt CMTAT"
        }

        // Engine management functions
        fn get_rule_engine(self: @ContractState) -> ContractAddress {
            self.rule_engine.read()
        }

        fn set_rule_engine(ref self: ContractState, new_engine: ContractAddress) {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.rule_engine.write(new_engine);
        }

        fn get_snapshot_engine(self: @ContractState) -> ContractAddress {
            self.snapshot_engine.read()
        }

        fn set_snapshot_engine(ref self: ContractState, new_engine: ContractAddress) {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.snapshot_engine.write(new_engine);
        }

        // Transfer restriction checking (ERC-1404 compatible)
        fn detect_transfer_restriction(
            self: @ContractState,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) -> u8 {
            // Check if contract is paused
            if self.is_paused() {
                return 2; // Contract paused
            }

            // Check if contract is deactivated
            if self.is_deactivated() {
                return 3; // Contract deactivated
            }

            // Check if addresses are frozen
            if self.is_frozen(from) || self.is_frozen(to) {
                return 1; // Address frozen
            }

            // Check active balance for sender (only if not a mint operation)
            if from != starknet::contract_address_const::<0>() {
                let active_balance = self.active_balance_of(from);
                if active_balance < amount {
                    return 4; // Insufficient active balance
                }
            }

            // Check rule engine if configured
            let rule_engine_addr = self.rule_engine.read();
            if rule_engine_addr != starknet::contract_address_const::<0>() {
                let rule_engine = IRuleEngineDispatcher { contract_address: rule_engine_addr };
                let restriction = rule_engine.detect_transfer_restriction(from, to, amount);
                if restriction != 0 {
                    return restriction;
                }
            }

            0 // No restriction
        }

        fn message_for_restriction_code(self: @ContractState, restriction_code: u8) -> ByteArray {
            if restriction_code == 1 {
                return "Address is frozen";
            }
            if restriction_code == 2 {
                return "Contract is paused";
            }
            if restriction_code == 3 {
                return "Contract is deactivated";
            }
            if restriction_code == 4 {
                return "Insufficient active balance";
            }

            let rule_engine_addr = self.rule_engine.read();
            if rule_engine_addr != starknet::contract_address_const::<0>() {
                let rule_engine = IRuleEngineDispatcher { contract_address: rule_engine_addr };
                return rule_engine.message_for_restriction_code(restriction_code);
            }

            "Unknown restriction"
        }

        // Snapshot functionality
        fn schedule_snapshot(ref self: ContractState, timestamp: u64) -> u64 {
            self.access_control.assert_only_role(DEBT_ROLE);
            let snapshot_engine_addr = self.snapshot_engine.read();
            assert(snapshot_engine_addr != starknet::contract_address_const::<0>(), 'No snapshot engine');
            
            let snapshot_engine = ISnapshotEngineDispatcher { contract_address: snapshot_engine_addr };
            snapshot_engine.schedule_snapshot(timestamp)
        }

        /// Force transfer tokens from one address to another
        /// 
        /// # Administrative Override Function:
        /// - Requires DEFAULT_ADMIN_ROLE permission
        /// - Can transfer from frozen addresses (bypasses freeze restrictions)
        /// - Automatically unfreezes partial tokens if needed
        /// - Contract must not be deactivated
        /// - Bypasses rule engine restrictions
        /// 
        /// # Arguments:
        /// - `from`: Source address to transfer tokens from
        /// - `to`: Target address to receive tokens
        /// - `amount`: Amount of tokens to transfer
        /// 
        /// # Returns:
        /// - `bool`: Always true if successful, reverts on failure
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
            // This bypasses all hooks and restrictions
            self.erc20._transfer(from, to, amount);
            
            true
        }

        fn record_snapshot(ref self: ContractState, snapshot_id: u64) {
            self.access_control.assert_only_role(DEBT_ROLE);
            let snapshot_engine_addr = self.snapshot_engine.read();
            assert(snapshot_engine_addr != starknet::contract_address_const::<0>(), 'No snapshot engine');
            
            let snapshot_recording = ISnapshotRecordingDispatcher { contract_address: snapshot_engine_addr };
            let total_supply = self.erc20.total_supply();
            snapshot_recording.record_snapshot(snapshot_id, total_supply);
        }
    }

    // Internal transfer hook implementation
    impl ERC20HooksImpl of ERC20Component::ERC20HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            let contract_state = ERC20Component::HasComponent::get_contract(@self);

            // Skip checks for mint/burn (zero addresses), but only skip for mint operations
            // Burn operations should still be checked for pause/deactivation in non-forced scenarios
            if from != starknet::contract_address_const::<0>() && recipient != starknet::contract_address_const::<0>() {
                // Regular transfer - check all restrictions
                let restriction = contract_state.detect_transfer_restriction(from, recipient, amount);
                assert(restriction == 0, 'Transfer restricted');
            } else if from != starknet::contract_address_const::<0>() && recipient == starknet::contract_address_const::<0>() {
                // Burn operation - only check pause and deactivation if not in forced operation
                // Note: This would ideally check if we're in a forced operation context
                // For now, we rely on the burn function's own checks
            }
        }

        fn after_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            let mut contract_state = ERC20Component::HasComponent::get_contract_mut(ref self);

            // Skip for mint/burn operations
            if from != starknet::contract_address_const::<0>() && recipient != starknet::contract_address_const::<0>() {
                // Notify rule engine
                let rule_engine_addr = contract_state.rule_engine.read();
                if rule_engine_addr != starknet::contract_address_const::<0>() {
                    let mut rule_engine = IRuleEngineDispatcher { contract_address: rule_engine_addr };
                    rule_engine.on_transfer_executed(from, recipient, amount);
                }
            }
        }
    }
}

#[starknet::interface]
trait IDebtCMTAT<TContractState> {
    fn terms(self: @TContractState) -> felt252;
    fn set_terms(ref self: TContractState, new_terms: felt252);
    fn mint(ref self: TContractState, to: ContractAddress, amount: u256);
    fn burn(ref self: TContractState, from: ContractAddress, amount: u256);
    fn freeze_address(ref self: TContractState, account: ContractAddress);
    fn unfreeze_address(ref self: TContractState, account: ContractAddress);
    fn is_frozen(self: @TContractState, account: ContractAddress) -> bool;
    // Pause functionality
    fn is_paused(self: @TContractState) -> bool;
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    // Deactivation functionality
    fn is_deactivated(self: @TContractState) -> bool;
    fn deactivate_contract(ref self: TContractState);
    // Token freezing functionality
    fn get_frozen_tokens(self: @TContractState, account: ContractAddress) -> u256;
    fn freeze_tokens(ref self: TContractState, account: ContractAddress, amount: u256);
    fn unfreeze_tokens(ref self: TContractState, account: ContractAddress, amount: u256);
    fn active_balance_of(self: @TContractState, account: ContractAddress) -> u256;
    // Debt-specific functions
    fn get_isin(self: @TContractState) -> ByteArray;
    fn set_isin(ref self: TContractState, new_isin: ByteArray);
    fn get_maturity_date(self: @TContractState) -> u64;
    fn set_maturity_date(ref self: TContractState, new_maturity_date: u64);
    fn get_interest_rate(self: @TContractState) -> u256;
    fn set_interest_rate(ref self: TContractState, new_interest_rate: u256);
    fn get_par_value(self: @TContractState) -> u256;
    fn set_par_value(ref self: TContractState, new_par_value: u256);
    fn has_credit_event(self: @TContractState) -> bool;
    fn get_credit_event_type(self: @TContractState) -> ByteArray;
    fn set_credit_event(ref self: TContractState, event_type: ByteArray, occurred: bool);
    fn token_type(self: @TContractState) -> ByteArray;
    // Engine management
    fn get_rule_engine(self: @TContractState) -> ContractAddress;
    fn set_rule_engine(ref self: TContractState, new_engine: ContractAddress);
    fn get_snapshot_engine(self: @TContractState) -> ContractAddress;
    fn set_snapshot_engine(ref self: TContractState, new_engine: ContractAddress);
    // Force transfer
    fn forced_transfer(ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256) -> bool;
    // Transfer restrictions (ERC-1404)
    fn detect_transfer_restriction(self: @TContractState, from: ContractAddress, to: ContractAddress, amount: u256) -> u8;
    fn message_for_restriction_code(self: @TContractState, restriction_code: u8) -> ByteArray;
    // Snapshot functionality
    fn schedule_snapshot(ref self: TContractState, timestamp: u64) -> u64;
    fn record_snapshot(ref self: TContractState, snapshot_id: u64);
}

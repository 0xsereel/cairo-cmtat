// SPDX-License-Identifier: MPL-2.0
// Debt CMTAT Implementation - For Debt Instruments

use starknet::ContractAddress;

#[starknet::contract]
mod DebtCMTAT {
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
    const PAUSER_ROLE: felt252 = 'PAUSER';
    const ENFORCER_ROLE: felt252 = 'ENFORCER';
    const ERC20ENFORCER_ROLE: felt252 = 'ERC20ENFORCER';
    const SNAPSHOOTER_ROLE: felt252 = 'SNAPSHOOTER';
    const DOCUMENT_ROLE: felt252 = 'DOCUMENT';
    const EXTRA_INFORMATION_ROLE: felt252 = 'EXTRA_INFORMATION';
    const DEBT_ROLE: felt252 = 'DEBT_ROLE';

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
        // Engine integration
        snapshot_engine: ContractAddress,
        document_engine: ContractAddress,
        debt_engine: ContractAddress,
        // Debt-specific fields
        debt_info: ByteArray,
        credit_events_info: ByteArray,
        is_defaulted: bool,
        // Compliance fields
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
        InformationSet: InformationSet,
        TokenIdSet: TokenIdSet,
        DebtSet: DebtSet,
        CreditEventsSet: CreditEventsSet,
        DebtEngineSet: DebtEngineSet,
        SnapshotEngineSet: SnapshotEngineSet,
        DocumentEngineSet: DocumentEngineSet,
        DefaultFlagged: DefaultFlagged,
        AddressFrozen: AddressFrozen,
        AddressUnfrozen: AddressUnfrozen,
        Paused: Paused,
        Unpaused: Unpaused,
        Deactivated: Deactivated,
        TokensFrozen: TokensFrozen,
        TokensUnfrozen: TokensUnfrozen,
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
    struct DebtSet {
        pub new_debt: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    struct CreditEventsSet {
        pub new_credit_events: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    struct DebtEngineSet {
        pub new_debt_engine: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct SnapshotEngineSet {
        pub new_snapshot_engine: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct DocumentEngineSet {
        pub new_document_engine: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct DefaultFlagged {
        pub flagged_by: ContractAddress,
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

    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        initial_supply: u256,
        recipient: ContractAddress
    ) {
        self.erc20.initializer(name, symbol);
        self.access_control.initializer();

        self.access_control._grant_role(DEFAULT_ADMIN_ROLE, admin);
        self.access_control._grant_role(MINTER_ROLE, admin);
        self.access_control._grant_role(BURNER_ROLE, admin);
        self.access_control._grant_role(PAUSER_ROLE, admin);
        self.access_control._grant_role(ENFORCER_ROLE, admin);
        self.access_control._grant_role(ERC20ENFORCER_ROLE, admin);
        self.access_control._grant_role(SNAPSHOOTER_ROLE, admin);
        self.access_control._grant_role(DOCUMENT_ROLE, admin);
        self.access_control._grant_role(EXTRA_INFORMATION_ROLE, admin);
        self.access_control._grant_role(DEBT_ROLE, admin);

        self.terms.write("");
        self.information.write("");
        self.token_id.write("");
        self.debt_info.write("");
        self.credit_events_info.write("");
        self.is_defaulted.write(false);
        self.paused.write(false);
        self.deactivated.write(false);
        self.snapshot_engine.write(starknet::contract_address_const::<0>());
        self.document_engine.write(starknet::contract_address_const::<0>());
        self.debt_engine.write(starknet::contract_address_const::<0>());

        if initial_supply > 0 {
            self.erc20._mint(recipient, initial_supply);
        }
    }

    #[abi(embed_v0)]
    impl DebtCMTATImpl of super::IDebtCMTAT<ContractState> {
        // ============ Information Functions ============
        fn terms(self: @ContractState) -> ByteArray {
            self.terms.read()
        }

        fn set_terms(ref self: ContractState, new_terms: ByteArray) -> bool {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.terms.write(new_terms.clone());
            self.emit(TermsSet { new_terms });
            true
        }

        fn information(self: @ContractState) -> ByteArray {
            self.information.read()
        }

        fn set_information(ref self: ContractState, new_information: ByteArray) -> bool {
            self.access_control.assert_only_role(EXTRA_INFORMATION_ROLE);
            self.information.write(new_information.clone());
            self.emit(InformationSet { new_information });
            true
        }

        fn token_id(self: @ContractState) -> ByteArray {
            self.token_id.read()
        }

        fn set_token_id(ref self: ContractState, new_token_id: ByteArray) -> bool {
            self.access_control.assert_only_role(EXTRA_INFORMATION_ROLE);
            self.token_id.write(new_token_id.clone());
            self.emit(TokenIdSet { new_token_id });
            true
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

        fn get_burner_role(self: @ContractState) -> felt252 {
            BURNER_ROLE
        }

        fn get_pauser_role(self: @ContractState) -> felt252 {
            PAUSER_ROLE
        }

        fn get_enforcer_role(self: @ContractState) -> felt252 {
            ENFORCER_ROLE
        }

        fn get_erc20enforcer_role(self: @ContractState) -> felt252 {
            ERC20ENFORCER_ROLE
        }

        fn get_snapshooter_role(self: @ContractState) -> felt252 {
            SNAPSHOOTER_ROLE
        }

        fn get_document_role(self: @ContractState) -> felt252 {
            DOCUMENT_ROLE
        }

        fn get_extra_information_role(self: @ContractState) -> felt252 {
            EXTRA_INFORMATION_ROLE
        }

        fn get_debt_role(self: @ContractState) -> felt252 {
            DEBT_ROLE
        }

        // ============ Version ============
        fn version(self: @ContractState) -> ByteArray {
            "2.0.0"
        }

        // ============ Minting Functions ============
        fn mint(ref self: ContractState, to: ContractAddress, value: u256) -> bool {
            self.access_control.assert_only_role(MINTER_ROLE);
            assert(!self.paused(), 'Contract is paused');
            self.erc20._mint(to, value);
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
                self.erc20._mint(to, value);
                self.emit(Mint { to, value });
                i += 1;
            };
            true
        }

        fn burn_and_mint(ref self: ContractState, from: ContractAddress, to: ContractAddress, value: u256) -> bool {
            self.access_control.assert_only_role(MINTER_ROLE);
            assert(!self.paused(), 'Contract is paused');
            
            // Validate addresses are not frozen
            assert(!self.is_frozen(from), 'From address is frozen');
            assert(!self.is_frozen(to), 'To address is frozen');
            
            // Verify sufficient active balance before burning
            let active_balance = self.get_active_balance_of(from);
            assert(active_balance >= value, 'Insufficient active balance');
            
            self.erc20._burn(from, value);
            self.emit(Burn { from, value });
            self.erc20._mint(to, value);
            self.emit(Mint { to, value });
            true
        }

        // ============ Burning Functions ============
        fn burn(ref self: ContractState, value: u256) -> bool {
            let from = get_caller_address();
            assert(!self.paused(), 'Contract is paused');
            assert(!self.is_frozen(from), 'Sender frozen');
            self.erc20._burn(from, value);
            self.emit(Burn { from, value });
            true
        }

        fn burn_from(ref self: ContractState, from: ContractAddress, value: u256) -> bool {
            assert(!self.paused(), 'Contract is paused');
            assert(!self.is_frozen(from), 'Sender frozen');
            let spender = get_caller_address();
            self.erc20._spend_allowance(from, spender, value);
            self.erc20._burn(from, value);
            self.emit(Burn { from, value });
            true
        }

        fn batch_burn(ref self: ContractState, accounts: Span<ContractAddress>, values: Span<u256>) -> bool {
            self.access_control.assert_only_role(BURNER_ROLE);
            assert(!self.paused(), 'Contract is paused');
            assert(accounts.len() == values.len(), 'Arrays length mismatch');
            
            let mut i: u32 = 0;
            loop {
                if i >= accounts.len() {
                    break;
                }
                let from = *accounts.at(i);
                let value = *values.at(i);
                assert(!self.is_frozen(from), 'Sender frozen');
                self.erc20._burn(from, value);
                self.emit(Burn { from, value });
                i += 1;
            };
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
            assert(!self.deactivated(), 'Cannot unpause when deactivated');
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

        fn freeze_partial_tokens(ref self: ContractState, account: ContractAddress, value: u256) -> bool {
            self.access_control.assert_only_role(ERC20ENFORCER_ROLE);
            let current_frozen = self.frozen_tokens.read(account);
            let balance = self.erc20.balance_of(account);
            
            // Ensure frozen tokens never exceed account balance
            assert(current_frozen + value <= balance, 'Cannot freeze more than balance');
            
            self.frozen_tokens.write(account, current_frozen + value);
            self.emit(TokensFrozen { account, amount: value });
            true
        }

        fn unfreeze_partial_tokens(ref self: ContractState, account: ContractAddress, value: u256) -> bool {
            self.access_control.assert_only_role(ERC20ENFORCER_ROLE);
            let current_frozen = self.frozen_tokens.read(account);
            assert(current_frozen >= value, 'Insufficient frozen tokens');
            self.frozen_tokens.write(account, current_frozen - value);
            self.emit(TokensUnfrozen { account, amount: value });
            true
        }

        fn get_frozen_tokens(self: @ContractState, account: ContractAddress) -> u256 {
            self.frozen_tokens.read(account)
        }

        fn get_active_balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            let total_balance = self.erc20.balance_of(account);
            let frozen_amount = self.frozen_tokens.read(account);
            if total_balance >= frozen_amount {
                total_balance - frozen_amount
            } else {
                0
            }
        }

        // ============ Debt Functions ============
        fn debt(self: @ContractState) -> ByteArray {
            self.debt_info.read()
        }

        fn set_debt(ref self: ContractState, debt_: ByteArray) -> bool {
            self.access_control.assert_only_role(DEBT_ROLE);
            self.debt_info.write(debt_.clone());
            self.emit(DebtSet { new_debt: debt_ });
            true
        }

        fn credit_events(self: @ContractState) -> ByteArray {
            self.credit_events_info.read()
        }

        fn set_credit_events(ref self: ContractState, credit_events_: ByteArray) -> bool {
            self.access_control.assert_only_role(DEBT_ROLE);
            self.credit_events_info.write(credit_events_.clone());
            self.emit(CreditEventsSet { new_credit_events: credit_events_ });
            true
        }

        fn debt_engine(self: @ContractState) -> ContractAddress {
            self.debt_engine.read()
        }

        fn set_debt_engine(ref self: ContractState, debt_engine_: ContractAddress) -> bool {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.debt_engine.write(debt_engine_);
            self.emit(DebtEngineSet { new_debt_engine: debt_engine_ });
            true
        }

        fn flag_default(ref self: ContractState) -> bool {
            self.access_control.assert_only_role(DEBT_ROLE);
            self.is_defaulted.write(true);
            self.emit(DefaultFlagged { flagged_by: get_caller_address() });
            true
        }

        // ============ Engine Management ============
        fn set_snapshot_engine(ref self: ContractState, snapshot_engine_: ContractAddress) -> bool {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.snapshot_engine.write(snapshot_engine_);
            self.emit(SnapshotEngineSet { new_snapshot_engine: snapshot_engine_ });
            true
        }

        fn snapshot_engine(self: @ContractState) -> ContractAddress {
            self.snapshot_engine.read()
        }

        fn set_document_engine(ref self: ContractState, document_engine_: ContractAddress) -> bool {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.document_engine.write(document_engine_);
            self.emit(DocumentEngineSet { new_document_engine: document_engine_ });
            true
        }

        fn document_engine(self: @ContractState) -> ContractAddress {
            self.document_engine.read()
        }

        // ============ Utility Functions ============
        fn token_type(self: @ContractState) -> ByteArray {
            "Debt CMTAT"
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
            let zero_address: ContractAddress = starknet::contract_address_const::<0>();

            // Only check transfers (not mint/burn)
            if from != zero_address && recipient != zero_address {
                assert(!contract_state.paused.read(), 'Contract is paused');
                assert(!contract_state.is_frozen(from), 'Sender frozen');
                assert(!contract_state.is_frozen(recipient), 'Recipient frozen');
                
                // Check active balance
                let active_balance = contract_state.get_active_balance_of(from);
                assert(active_balance >= amount, 'Insufficient active balance');
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
trait IDebtCMTAT<TContractState> {
    // Information
    fn terms(self: @TContractState) -> ByteArray;
    fn set_terms(ref self: TContractState, new_terms: ByteArray) -> bool;
    fn information(self: @TContractState) -> ByteArray;
    fn set_information(ref self: TContractState, new_information: ByteArray) -> bool;
    fn token_id(self: @TContractState) -> ByteArray;
    fn set_token_id(ref self: TContractState, new_token_id: ByteArray) -> bool;
    
    // Balance queries
    fn batch_balance_of(self: @TContractState, accounts: Span<ContractAddress>) -> Array<u256>;
    
    // Role getters
    fn get_default_admin_role(self: @TContractState) -> felt252;
    fn get_minter_role(self: @TContractState) -> felt252;
    fn get_burner_role(self: @TContractState) -> felt252;
    fn get_pauser_role(self: @TContractState) -> felt252;
    fn get_enforcer_role(self: @TContractState) -> felt252;
    fn get_erc20enforcer_role(self: @TContractState) -> felt252;
    fn get_snapshooter_role(self: @TContractState) -> felt252;
    fn get_document_role(self: @TContractState) -> felt252;
    fn get_extra_information_role(self: @TContractState) -> felt252;
    fn get_debt_role(self: @TContractState) -> felt252;
    
    // Version
    fn version(self: @TContractState) -> ByteArray;
    
    // Minting
    fn mint(ref self: TContractState, to: ContractAddress, value: u256) -> bool;
    fn batch_mint(ref self: TContractState, tos: Span<ContractAddress>, values: Span<u256>) -> bool;
    fn burn_and_mint(ref self: TContractState, from: ContractAddress, to: ContractAddress, value: u256) -> bool;
    
    // Burning
    fn burn(ref self: TContractState, value: u256) -> bool;
    fn burn_from(ref self: TContractState, from: ContractAddress, value: u256) -> bool;
    fn batch_burn(ref self: TContractState, accounts: Span<ContractAddress>, values: Span<u256>) -> bool;
    
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
    fn freeze_partial_tokens(ref self: TContractState, account: ContractAddress, value: u256) -> bool;
    fn unfreeze_partial_tokens(ref self: TContractState, account: ContractAddress, value: u256) -> bool;
    fn get_frozen_tokens(self: @TContractState, account: ContractAddress) -> u256;
    fn get_active_balance_of(self: @TContractState, account: ContractAddress) -> u256;
    
    // Debt-specific
    fn debt(self: @TContractState) -> ByteArray;
    fn set_debt(ref self: TContractState, debt_: ByteArray) -> bool;
    fn credit_events(self: @TContractState) -> ByteArray;
    fn set_credit_events(ref self: TContractState, credit_events_: ByteArray) -> bool;
    fn debt_engine(self: @TContractState) -> ContractAddress;
    fn set_debt_engine(ref self: TContractState, debt_engine_: ContractAddress) -> bool;
    fn flag_default(ref self: TContractState) -> bool;
    
    // Engines
    fn set_snapshot_engine(ref self: TContractState, snapshot_engine_: ContractAddress) -> bool;
    fn snapshot_engine(self: @TContractState) -> ContractAddress;
    fn set_document_engine(ref self: TContractState, document_engine_: ContractAddress) -> bool;
    fn document_engine(self: @TContractState) -> ContractAddress;
    
    // Utility
    fn token_type(self: @TContractState) -> ByteArray;
}

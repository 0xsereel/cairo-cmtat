// SPDX-License-Identifier: MPL-2.0
// Allowlist CMTAT Implementation - Transfer restrictions via allowlist

use starknet::ContractAddress;

#[starknet::contract]
mod AllowlistCMTAT {
    use openzeppelin::token::erc20::ERC20Component;
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

    // ERC20 Hooks implementation with allowlist validation
    impl ERC20HooksImpl of ERC20Component::ERC20HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            let contract_state = ERC20Component::HasComponent::get_contract(@self);
            
            // Short-circuit if allowlist feature is disabled
            if !contract_state.allowlist_enabled.read() {
                return;
            }
            
            let zero_address: ContractAddress = starknet::contract_address_const::<0>();
            
            // Skip allowlist check for minting (from == 0) and burning (recipient == 0)
            if from != zero_address && recipient != zero_address {
                // Regular transfer - both parties must be on allowlist
                assert(contract_state.allowlist.read(from), 'Sender not on allowlist');
                assert(contract_state.allowlist.read(recipient), 'Recipient not on allowlist');
            } else if recipient != zero_address {
                // Minting - recipient must be on allowlist
                assert(contract_state.allowlist.read(recipient), 'Recipient not on allowlist');
            }
            // Burning doesn't require allowlist check
        }

        fn after_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {}
    }

    const MINTER_ROLE: felt252 = 'MINTER';
    const BURNER_ROLE: felt252 = 'BURNER';
    const PAUSER_ROLE: felt252 = 'PAUSER';
    const ENFORCER_ROLE: felt252 = 'ENFORCER';
    const ERC20ENFORCER_ROLE: felt252 = 'ERC20ENFORCER';
    const ALLOWLIST_ADMIN_ROLE: felt252 = 'ALLOWLIST_ADMIN';
    const SNAPSHOOTER_ROLE: felt252 = 'SNAPSHOOTER';
    const DOCUMENT_ROLE: felt252 = 'DOCUMENT';
    const EXTRA_INFORMATION_ROLE: felt252 = 'EXTRA_INFORMATION';

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
        paused: bool,
        deactivated: bool,
        // Allowlist storage
        allowlist_enabled: bool,
        allowlist: LegacyMap<ContractAddress, bool>,
        // Partial token freezing
        frozen_addresses: LegacyMap<ContractAddress, bool>,
        frozen_tokens: LegacyMap<ContractAddress, u256>,
        // Engine addresses
        snapshot_engine: ContractAddress,
        document_engine: ContractAddress,
        // Trusted forwarder for meta-transactions
        trusted_forwarder: ContractAddress,
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
        AddressAddedToAllowlist: AddressAddedToAllowlist,
        AddressRemovedFromAllowlist: AddressRemovedFromAllowlist,
        AllowlistEnabled: AllowlistEnabled,
        AllowlistDisabled: AllowlistDisabled,
        AddressFrozen: AddressFrozen,
        AddressUnfrozen: AddressUnfrozen,
        TokensFrozen: TokensFrozen,
        TokensUnfrozen: TokensUnfrozen,
        Mint: Mint,
        Burn: Burn,
        ForcedBurn: ForcedBurn,
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
    struct TokenIdSet {
        pub new_token_id: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    struct AddressRemovedFromAllowlist {
        #[key]
        pub account: ContractAddress,
        pub removed_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct AllowlistEnabled {
        pub enabled_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct AllowlistDisabled {
        pub disabled_by: ContractAddress,
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
    struct ForcedBurn {
        #[key]
        pub from: ContractAddress,
        pub value: u256,
        pub admin: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        forwarder_irrevocable: ContractAddress,
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
        self.access_control._grant_role(ALLOWLIST_ADMIN_ROLE, admin);
        self.access_control._grant_role(SNAPSHOOTER_ROLE, admin);
        self.access_control._grant_role(DOCUMENT_ROLE, admin);
        self.access_control._grant_role(EXTRA_INFORMATION_ROLE, admin);

        self.terms.write("");
        self.information.write("");
        self.token_id.write("");
        self.paused.write(false);
        self.deactivated.write(false);
        self.allowlist_enabled.write(false);
        self.trusted_forwarder.write(forwarder_irrevocable);
        self.snapshot_engine.write(starknet::contract_address_const::<0>());
        self.document_engine.write(starknet::contract_address_const::<0>());

        // Add recipient to allowlist if initial supply is provided
        if initial_supply > 0 {
            self.allowlist.write(recipient, true);
            self.emit(AddressAddedToAllowlist { account: recipient, added_by: admin });
            self.erc20._mint(recipient, initial_supply);
        }
    }

    #[abi(embed_v0)]
    impl AllowlistCMTATImpl of super::IAllowlistCMTAT<ContractState> {
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
            self.erc20._burn(from, value);
            self.emit(Burn { from, value });
            true
        }

        fn burn_from(ref self: ContractState, from: ContractAddress, value: u256) -> bool {
            assert(!self.paused(), 'Contract is paused');
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

        // ============ Allowlist Functions ============
        fn enable_allowlist(ref self: ContractState, status: bool) -> bool {
            self.access_control.assert_only_role(ALLOWLIST_ADMIN_ROLE);
            self.allowlist_enabled.write(status);
            if status {
                self.emit(AllowlistEnabled { enabled_by: get_caller_address() });
            } else {
                self.emit(AllowlistDisabled { disabled_by: get_caller_address() });
            }
            true
        }

        fn is_allowlist_enabled(self: @ContractState) -> bool {
            self.allowlist_enabled.read()
        }

        fn set_address_allowlist(ref self: ContractState, account: ContractAddress, status: bool) -> bool {
            self.access_control.assert_only_role(ALLOWLIST_ADMIN_ROLE);
            self.allowlist.write(account, status);
            let caller = get_caller_address();
            if status {
                self.emit(AddressAddedToAllowlist { account, added_by: caller });
            } else {
                self.emit(AddressRemovedFromAllowlist { account, removed_by: caller });
            }
            true
        }

        fn batch_set_address_allowlist(ref self: ContractState, accounts: Span<ContractAddress>, statuses: Span<bool>) -> bool {
            self.access_control.assert_only_role(ALLOWLIST_ADMIN_ROLE);
            assert(accounts.len() == statuses.len(), 'Arrays length mismatch');
            
            let caller = get_caller_address();
            let mut i: u32 = 0;
            loop {
                if i >= accounts.len() {
                    break;
                }
                let account = *accounts.at(i);
                let status = *statuses.at(i);
                self.allowlist.write(account, status);
                if status {
                    self.emit(AddressAddedToAllowlist { account, added_by: caller });
                } else {
                    self.emit(AddressRemovedFromAllowlist { account, removed_by: caller });
                }
                i += 1;
            };
            true
        }

        fn is_allowlisted(self: @ContractState, account: ContractAddress) -> bool {
            self.allowlist.read(account)
        }

        // ============ Engine Management ============
        fn set_snapshot_engine(ref self: ContractState, snapshot_engine_: ContractAddress) -> bool {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.snapshot_engine.write(snapshot_engine_);
            true
        }

        fn snapshot_engine(self: @ContractState) -> ContractAddress {
            self.snapshot_engine.read()
        }

        fn set_document_engine(ref self: ContractState, document_engine_: ContractAddress) -> bool {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.document_engine.write(document_engine_);
            true
        }

        fn document_engine(self: @ContractState) -> ContractAddress {
            self.document_engine.read()
        }

        // ============ Meta-Transaction Support ============
        fn is_trusted_forwarder(self: @ContractState, forwarder: ContractAddress) -> bool {
            forwarder == self.trusted_forwarder.read()
        }

        // ============ Utility Functions ============
        fn token_type(self: @ContractState) -> ByteArray {
            "Allowlist CMTAT"
        }
    }
}

#[starknet::interface]
trait IAllowlistCMTAT<TContractState> {
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
    
    // Allowlist
    fn enable_allowlist(ref self: TContractState, status: bool) -> bool;
    fn is_allowlist_enabled(self: @TContractState) -> bool;
    fn set_address_allowlist(ref self: TContractState, account: ContractAddress, status: bool) -> bool;
    fn batch_set_address_allowlist(ref self: TContractState, accounts: Span<ContractAddress>, statuses: Span<bool>) -> bool;
    fn is_allowlisted(self: @TContractState, account: ContractAddress) -> bool;
    
    // Engines
    fn set_snapshot_engine(ref self: TContractState, snapshot_engine_: ContractAddress) -> bool;
    fn snapshot_engine(self: @TContractState) -> ContractAddress;
    fn set_document_engine(ref self: TContractState, document_engine_: ContractAddress) -> bool;
    fn document_engine(self: @TContractState) -> ContractAddress;
    
    // Meta-transactions
    fn is_trusted_forwarder(self: @TContractState, forwarder: ContractAddress) -> bool;
    
    // Utility
    fn token_type(self: @TContractState) -> ByteArray;
}

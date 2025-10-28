// SPDX-License-Identifier: MPL-2.0
// Debt CMTAT Implementation - For Debt Instruments

use starknet::ContractAddress;

#[starknet::contract]
mod DebtCMTAT {
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
        flag: felt252,
        // Debt-specific fields
        isin: ByteArray,
        maturity_date: u64,
        interest_rate: u256,
        par_value: u256,
        credit_event_occurred: bool,
        credit_event_type: ByteArray,
        frozen_addresses: LegacyMap<ContractAddress, bool>,
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
        FlagSet: FlagSet,
        ISINSet: ISINSet,
        MaturityDateSet: MaturityDateSet,
        InterestRateSet: InterestRateSet,
        ParValueSet: ParValueSet,
        CreditEventSet: CreditEventSet,
        AddressFrozen: AddressFrozen,
        AddressUnfrozen: AddressUnfrozen,
    }

    #[derive(Drop, starknet::Event)]
    struct TermsSet {
        pub previous_terms: felt252,
        pub new_terms: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct FlagSet {
        pub previous_flag: felt252,
        pub new_flag: felt252,
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

    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        initial_supply: u256,
        recipient: ContractAddress,
        terms: felt252,
        flag: felt252,
        isin: ByteArray,
        maturity_date: u64,
        interest_rate: u256,
        par_value: u256
    ) {
        self.erc20.initializer(name, symbol);
        self.access_control.initializer();

        self.access_control._grant_role(DEFAULT_ADMIN_ROLE, admin);
        self.access_control._grant_role(MINTER_ROLE, admin);
        self.access_control._grant_role(BURNER_ROLE, admin);
        self.access_control._grant_role(DEBT_ROLE, admin);

        self.terms.write(terms);
        self.flag.write(flag);
        self.isin.write(isin);
        self.maturity_date.write(maturity_date);
        self.interest_rate.write(interest_rate);
        self.par_value.write(par_value);
        self.credit_event_occurred.write(false);

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

        fn flag(self: @ContractState) -> felt252 {
            self.flag.read()
        }

        fn set_flag(ref self: ContractState, new_flag: felt252) {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            let previous_flag = self.flag.read();
            self.flag.write(new_flag);
            self.emit(FlagSet { previous_flag, new_flag });
        }

        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
            self.access_control.assert_only_role(MINTER_ROLE);
            assert(!self.is_frozen(to), 'Address is frozen');
            self.erc20._mint(to, amount);
        }

        fn burn(ref self: ContractState, from: ContractAddress, amount: u256) {
            self.access_control.assert_only_role(BURNER_ROLE);
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
    }
}

#[starknet::interface]
trait IDebtCMTAT<TContractState> {
    fn terms(self: @TContractState) -> felt252;
    fn set_terms(ref self: TContractState, new_terms: felt252);
    fn flag(self: @TContractState) -> felt252;
    fn set_flag(ref self: TContractState, new_flag: felt252);
    fn mint(ref self: TContractState, to: ContractAddress, amount: u256);
    fn burn(ref self: TContractState, from: ContractAddress, amount: u256);
    fn freeze_address(ref self: TContractState, account: ContractAddress);
    fn unfreeze_address(ref self: TContractState, account: ContractAddress);
    fn is_frozen(self: @TContractState, account: ContractAddress) -> bool;
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
}

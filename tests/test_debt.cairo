// SPDX-License-Identifier: MPL-2.0
// DebtComponent: structured debt information and credit events.

use cairo_cmtat::components::debt::DebtComponent;
use cairo_cmtat::interfaces::debt::{
    CreditEvents, DebtIdentifier, DebtInformation, DebtInstrument, IDebtModuleDispatcher,
    IDebtModuleDispatcherTrait, IDebtModuleSafeDispatcher, IDebtModuleSafeDispatcherTrait,
};
use cairo_cmtat::roles::DEBT_ROLE;
use openzeppelin::access::accesscontrol::AccessControlComponent;
use openzeppelin::interfaces::accesscontrol::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin_testing::{EventSpyExt, spy_events};
use snforge_std::start_cheat_caller_address;
use starknet::ContractAddress;
use crate::utils::{ADMIN, HOLDER, OTHER, RECIPIENT, SUPPLY, ZERO, assert_reverted_with};

/// Debt manager.
const DEBT_MANAGER: ContractAddress = OTHER;

fn setup() -> ContractAddress {
    let mut calldata = array![];
    calldata.append_serde(18_u8);
    calldata.append_serde(SUPPLY);
    calldata.append_serde(HOLDER);
    calldata.append_serde(ADMIN);
    let token = openzeppelin_testing::declare_and_deploy("CommonMock", calldata);
    start_cheat_caller_address(token, ADMIN);
    IAccessControlDispatcher { contract_address: token }.grant_role(DEBT_ROLE, DEBT_MANAGER);
    start_cheat_caller_address(token, DEBT_MANAGER);
    token
}

fn debt_module(token: ContractAddress) -> IDebtModuleDispatcher {
    IDebtModuleDispatcher { contract_address: token }
}

fn instrument(interest_rate: u256) -> DebtInstrument {
    DebtInstrument {
        interest_rate,
        par_value: 1_000,
        minimum_denomination: 100,
        issuance_date: "2026-01-01",
        maturity_date: "2031-01-01",
        coupon_payment_frequency: "Annual",
        interest_schedule_format: "Fixed",
        interest_payment_date: "01-01",
        day_count_convention: "30/360",
        business_day_convention: "Following",
        currency: "CHF",
        currency_contract: RECIPIENT,
    }
}

fn debt_information() -> DebtInformation {
    DebtInformation {
        debt_identifier: DebtIdentifier {
            issuer_name: "Issuer SA",
            issuer_description: "Swiss issuer",
            guarantor: "Guarantor AG",
            debt_holder: "Holder",
        },
        debt_instrument: instrument(250),
    }
}

fn empty_debt() -> DebtInformation {
    DebtInformation {
        debt_identifier: DebtIdentifier {
            issuer_name: "", issuer_description: "", guarantor: "", debt_holder: "",
        },
        debt_instrument: DebtInstrument {
            interest_rate: 0,
            par_value: 0,
            minimum_denomination: 0,
            issuance_date: "",
            maturity_date: "",
            coupon_payment_frequency: "",
            interest_schedule_format: "",
            interest_payment_date: "",
            day_count_convention: "",
            business_day_convention: "",
            currency: "",
            currency_contract: ZERO,
        },
    }
}

#[test]
fn starts_empty() {
    let token = setup();
    assert_eq!(debt_module(token).debt(), empty_debt());
    assert_eq!(
        debt_module(token).credit_events(),
        CreditEvents { flag_default: false, flag_redeemed: false, rating: "" },
    );
}

#[test]
fn set_debt_stores_and_emits() {
    let token = setup();
    let mut spy = spy_events();
    debt_module(token).set_debt(debt_information());
    assert_eq!(debt_module(token).debt(), debt_information());
    spy
        .assert_only_event(
            token, DebtComponent::Event::DebtLogEvent(DebtComponent::DebtLogEvent {}),
        );
}

#[test]
fn set_debt_instrument_keeps_identifier() {
    let token = setup();
    debt_module(token).set_debt(debt_information());
    let mut spy = spy_events();
    debt_module(token).set_debt_instrument(instrument(400));
    let mut expected = debt_information();
    expected.debt_instrument = instrument(400);
    assert_eq!(debt_module(token).debt(), expected);
    spy
        .assert_only_event(
            token,
            DebtComponent::Event::DebtInstrumentLogEvent(DebtComponent::DebtInstrumentLogEvent {}),
        );
}

#[test]
fn set_credit_events_stores_and_emits() {
    let token = setup();
    let events = CreditEvents { flag_default: true, flag_redeemed: false, rating: "BBB" };
    let mut spy = spy_events();
    debt_module(token).set_credit_events(events.clone());
    assert_eq!(debt_module(token).credit_events(), events);
    spy
        .assert_only_event(
            token,
            DebtComponent::Event::CreditEventsLogEvent(DebtComponent::CreditEventsLogEvent {}),
        );
}

#[test]
#[feature("safe_dispatcher")]
fn setters_require_debt_role() {
    let token = setup();
    start_cheat_caller_address(token, HOLDER);
    let safe = IDebtModuleSafeDispatcher { contract_address: token };
    let missing_role = array![AccessControlComponent::Errors::MISSING_ROLE].span();
    assert_reverted_with(safe.set_debt(debt_information()), missing_role);
    assert_reverted_with(safe.set_debt_instrument(instrument(1)), missing_role);
    assert_reverted_with(
        safe
            .set_credit_events(
                CreditEvents { flag_default: true, flag_redeemed: true, rating: "D" },
            ),
        missing_role,
    );
}

#[test]
fn admin_can_set_debt() {
    let token = setup();
    start_cheat_caller_address(token, ADMIN);
    debt_module(token).set_debt(debt_information());
    assert_eq!(debt_module(token).debt(), debt_information());
}

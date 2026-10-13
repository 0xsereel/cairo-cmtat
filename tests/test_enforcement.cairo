// SPDX-License-Identifier: MPL-2.0
// EnforcementComponent: address freeze.

use cairo_cmtat::components::enforcement::EnforcementComponent;
use cairo_cmtat::errors;
use cairo_cmtat::interfaces::enforcement::{
    ICMTATEnforcementDispatcher, ICMTATEnforcementDispatcherTrait, ICMTATEnforcementSafeDispatcher,
    ICMTATEnforcementSafeDispatcherTrait, IERC3643EnforcementDispatcher,
    IERC3643EnforcementDispatcherTrait, IERC3643EnforcementSafeDispatcher,
    IERC3643EnforcementSafeDispatcherTrait,
};
use cairo_cmtat::roles::ENFORCER_ROLE;
use openzeppelin::access::accesscontrol::AccessControlComponent;
use openzeppelin::interfaces::accesscontrol::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin_testing::{EventSpyExt, spy_events};
use snforge_std::start_cheat_caller_address;
use starknet::ContractAddress;
use crate::utils::{ADMIN, ENFORCER, HOLDER, OTHER, RECIPIENT, ZERO, assert_reverted_with};

fn setup() -> ContractAddress {
    let token = openzeppelin_testing::declare_and_deploy("EnforcementMock", array![ADMIN.into()]);
    start_cheat_caller_address(token, ADMIN);
    IAccessControlDispatcher { contract_address: token }.grant_role(ENFORCER_ROLE, ENFORCER);
    start_cheat_caller_address(token, ENFORCER);
    token
}

fn enforcement(token: ContractAddress) -> IERC3643EnforcementDispatcher {
    IERC3643EnforcementDispatcher { contract_address: token }
}

fn safe_enforcement(token: ContractAddress) -> IERC3643EnforcementSafeDispatcher {
    IERC3643EnforcementSafeDispatcher { contract_address: token }
}

fn address_frozen_event(
    account: ContractAddress, is_frozen: bool, enforcer: ContractAddress, data: Span<felt252>,
) -> EnforcementComponent::Event {
    EnforcementComponent::Event::AddressFrozen(
        EnforcementComponent::AddressFrozen { account, is_frozen, enforcer, data },
    )
}

//
// set_address_frozen
//

#[test]
fn freeze_and_unfreeze() {
    let token = setup();
    assert!(!enforcement(token).is_frozen(HOLDER));
    enforcement(token).set_address_frozen(HOLDER, true);
    assert!(enforcement(token).is_frozen(HOLDER));
    enforcement(token).set_address_frozen(HOLDER, false);
    assert!(!enforcement(token).is_frozen(HOLDER));
}

#[test]
fn freeze_emits_event_with_empty_data() {
    let token = setup();
    let mut spy = spy_events();
    enforcement(token).set_address_frozen(HOLDER, true);
    spy.assert_only_event(token, address_frozen_event(HOLDER, true, ENFORCER, array![].span()));
}

#[test]
fn freeze_same_value_still_emits() {
    let token = setup();
    let mut spy = spy_events();
    enforcement(token).set_address_frozen(HOLDER, false);
    spy.assert_only_event(token, address_frozen_event(HOLDER, false, ENFORCER, array![].span()));
}

#[test]
fn admin_can_freeze() {
    let token = setup();
    start_cheat_caller_address(token, ADMIN);
    enforcement(token).set_address_frozen(HOLDER, true);
    assert!(enforcement(token).is_frozen(HOLDER));
}

#[test]
#[feature("safe_dispatcher")]
fn freeze_requires_enforcer_role() {
    let token = setup();
    start_cheat_caller_address(token, OTHER);
    assert_reverted_with(
        safe_enforcement(token).set_address_frozen(HOLDER, true),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn freeze_rejects_zero_address() {
    let token = setup();
    assert_reverted_with(
        safe_enforcement(token).set_address_frozen(ZERO, true),
        array![errors::ENF_ZERO_ADDRESS_NOT_ALLOWED].span(),
    );
}

//
// set_address_frozen_with_data
//

#[test]
fn freeze_with_data_emits_data() {
    let token = setup();
    let mut spy = spy_events();
    let data = array!['reason', 42].span();
    ICMTATEnforcementDispatcher { contract_address: token }
        .set_address_frozen_with_data(HOLDER, true, data);
    assert!(enforcement(token).is_frozen(HOLDER));
    spy.assert_only_event(token, address_frozen_event(HOLDER, true, ENFORCER, data));
}

#[test]
#[feature("safe_dispatcher")]
fn freeze_with_data_requires_enforcer_role() {
    let token = setup();
    start_cheat_caller_address(token, OTHER);
    assert_reverted_with(
        ICMTATEnforcementSafeDispatcher { contract_address: token }
            .set_address_frozen_with_data(HOLDER, true, array![].span()),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn freeze_with_data_rejects_zero_address() {
    let token = setup();
    assert_reverted_with(
        ICMTATEnforcementSafeDispatcher { contract_address: token }
            .set_address_frozen_with_data(ZERO, true, array![].span()),
        array![errors::ENF_ZERO_ADDRESS_NOT_ALLOWED].span(),
    );
}

//
// batch_set_address_frozen
//

#[test]
fn batch_freeze_sets_each_status_and_emits_per_account() {
    let token = setup();
    enforcement(token).set_address_frozen(OTHER, true);
    let mut spy = spy_events();
    enforcement(token)
        .batch_set_address_frozen(
            array![HOLDER, RECIPIENT, OTHER].span(), array![true, true, false].span(),
        );
    assert!(enforcement(token).is_frozen(HOLDER));
    assert!(enforcement(token).is_frozen(RECIPIENT));
    assert!(!enforcement(token).is_frozen(OTHER));
    let empty = array![].span();
    spy.assert_emitted_single(token, address_frozen_event(HOLDER, true, ENFORCER, empty));
    spy.assert_emitted_single(token, address_frozen_event(RECIPIENT, true, ENFORCER, empty));
    spy.assert_only_event(token, address_frozen_event(OTHER, false, ENFORCER, empty));
}

#[test]
#[feature("safe_dispatcher")]
fn batch_freeze_requires_enforcer_role() {
    let token = setup();
    start_cheat_caller_address(token, OTHER);
    assert_reverted_with(
        safe_enforcement(token)
            .batch_set_address_frozen(array![HOLDER].span(), array![true].span()),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn batch_freeze_rejects_empty_accounts() {
    let token = setup();
    assert_reverted_with(
        safe_enforcement(token).batch_set_address_frozen(array![].span(), array![].span()),
        array![errors::ENF_EMPTY_ACCOUNTS].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn batch_freeze_rejects_length_mismatch() {
    let token = setup();
    assert_reverted_with(
        safe_enforcement(token)
            .batch_set_address_frozen(array![HOLDER, OTHER].span(), array![true].span()),
        array![errors::ENF_ACCOUNTS_VALUES_LEN_MISMATCH].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn batch_freeze_rejects_zero_address_atomically() {
    let token = setup();
    assert_reverted_with(
        safe_enforcement(token)
            .batch_set_address_frozen(array![HOLDER, ZERO].span(), array![true, true].span()),
        array![errors::ENF_ZERO_ADDRESS_NOT_ALLOWED].span(),
    );
    assert!(!enforcement(token).is_frozen(HOLDER));
}

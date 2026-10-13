// SPDX-License-Identifier: MPL-2.0
// PauseComponent: ERC-3643 pause and ERC-8343 deactivation.

use cairo_cmtat::components::pause::PauseComponent;
use cairo_cmtat::errors;
use cairo_cmtat::interfaces::pause::{
    IERC3643PauseDispatcher, IERC3643PauseDispatcherTrait, IERC3643PauseSafeDispatcher,
    IERC3643PauseSafeDispatcherTrait, IERC8343Dispatcher, IERC8343DispatcherTrait,
    IERC8343SafeDispatcher, IERC8343SafeDispatcherTrait, IERC8343_ID,
};
use cairo_cmtat::mocks::pause_mock::{
    IPauseMockDispatcher, IPauseMockDispatcherTrait, IPauseMockSafeDispatcher,
    IPauseMockSafeDispatcherTrait,
};
use cairo_cmtat::roles::PAUSER_ROLE;
use openzeppelin::access::accesscontrol::AccessControlComponent;
use openzeppelin::interfaces::accesscontrol::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use openzeppelin_testing::{EventSpyExt, spy_events};
use snforge_std::start_cheat_caller_address;
use starknet::ContractAddress;
use crate::utils::{ADMIN, OTHER, PAUSER, assert_reverted_with};

fn setup() -> ContractAddress {
    let token = openzeppelin_testing::declare_and_deploy("PauseMock", array![ADMIN.into()]);
    start_cheat_caller_address(token, ADMIN);
    IAccessControlDispatcher { contract_address: token }.grant_role(PAUSER_ROLE, PAUSER);
    token
}

fn pause(token: ContractAddress) -> IERC3643PauseDispatcher {
    IERC3643PauseDispatcher { contract_address: token }
}

fn erc8343(token: ContractAddress) -> IERC8343Dispatcher {
    IERC8343Dispatcher { contract_address: token }
}

fn paused_token() -> ContractAddress {
    let token = setup();
    start_cheat_caller_address(token, PAUSER);
    pause(token).pause();
    token
}

fn deactivated_token() -> ContractAddress {
    let token = paused_token();
    start_cheat_caller_address(token, ADMIN);
    erc8343(token).deactivate_contract();
    token
}

//
// SRC5
//

#[test]
fn erc8343_id_matches_extended_selectors() {
    let a: u256 = selector!("deactivate_contract()").into();
    let b: u256 = selector!("deactivated()->E((),())").into();
    let id: u256 = IERC8343_ID.into();
    assert_eq!(id, a ^ b);
}

#[test]
fn initializer_registers_erc8343() {
    let token = setup();
    assert!(ISRC5Dispatcher { contract_address: token }.supports_interface(IERC8343_ID));
}

//
// pause / unpause
//

#[test]
fn starts_unpaused_and_active() {
    let token = setup();
    assert!(!pause(token).paused());
    assert!(!erc8343(token).deactivated());
}

#[test]
fn pause_by_pauser_emits_event() {
    let token = setup();
    let mut spy = spy_events();
    start_cheat_caller_address(token, PAUSER);
    pause(token).pause();
    assert!(pause(token).paused());
    spy
        .assert_only_event(
            token, PauseComponent::Event::Paused(PauseComponent::Paused { account: PAUSER }),
        );
}

#[test]
fn admin_can_pause() {
    let token = setup();
    pause(token).pause();
    assert!(pause(token).paused());
}

#[test]
#[feature("safe_dispatcher")]
fn pause_requires_pauser_role() {
    let token = setup();
    start_cheat_caller_address(token, OTHER);
    assert_reverted_with(
        IERC3643PauseSafeDispatcher { contract_address: token }.pause(),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn pause_when_paused_reverts() {
    let token = paused_token();
    assert_reverted_with(
        IERC3643PauseSafeDispatcher { contract_address: token }.pause(),
        array![errors::ENFORCED_PAUSE].span(),
    );
}

#[test]
fn unpause_by_pauser_emits_event() {
    let token = paused_token();
    let mut spy = spy_events();
    pause(token).unpause();
    assert!(!pause(token).paused());
    spy
        .assert_only_event(
            token, PauseComponent::Event::Unpaused(PauseComponent::Unpaused { account: PAUSER }),
        );
}

#[test]
#[feature("safe_dispatcher")]
fn unpause_requires_pauser_role() {
    let token = paused_token();
    start_cheat_caller_address(token, OTHER);
    assert_reverted_with(
        IERC3643PauseSafeDispatcher { contract_address: token }.unpause(),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn unpause_when_unpaused_reverts() {
    let token = setup();
    start_cheat_caller_address(token, PAUSER);
    assert_reverted_with(
        IERC3643PauseSafeDispatcher { contract_address: token }.unpause(),
        array![errors::EXPECTED_PAUSE].span(),
    );
}

//
// deactivate_contract
//

#[test]
fn deactivate_by_admin_emits_event() {
    let token = paused_token();
    let mut spy = spy_events();
    start_cheat_caller_address(token, ADMIN);
    erc8343(token).deactivate_contract();
    assert!(erc8343(token).deactivated());
    assert!(pause(token).paused());
    spy
        .assert_only_event(
            token,
            PauseComponent::Event::Deactivated(PauseComponent::Deactivated { account: ADMIN }),
        );
}

#[test]
#[feature("safe_dispatcher")]
fn deactivate_requires_default_admin() {
    let token = paused_token();
    start_cheat_caller_address(token, PAUSER);
    assert_reverted_with(
        IERC8343SafeDispatcher { contract_address: token }.deactivate_contract(),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn deactivate_requires_pause() {
    let token = setup();
    assert_reverted_with(
        IERC8343SafeDispatcher { contract_address: token }.deactivate_contract(),
        array![errors::EXPECTED_PAUSE].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn deactivate_twice_reverts() {
    let token = deactivated_token();
    assert_reverted_with(
        IERC8343SafeDispatcher { contract_address: token }.deactivate_contract(),
        array![errors::ALREADY_DEACTIVATED].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn unpause_after_deactivation_reverts() {
    let token = deactivated_token();
    start_cheat_caller_address(token, PAUSER);
    assert_reverted_with(
        IERC3643PauseSafeDispatcher { contract_address: token }.unpause(),
        array![errors::PAUSE_CONTRACT_IS_DEACTIVATED].span(),
    );
}

//
// internal guards
//

#[test]
fn guards_pass_when_active() {
    let mock = IPauseMockDispatcher { contract_address: setup() };
    assert!(mock.when_not_paused());
    assert!(mock.when_not_deactivated());
}

#[test]
#[feature("safe_dispatcher")]
fn assert_not_paused_reverts_when_paused() {
    let token = paused_token();
    assert_reverted_with(
        IPauseMockSafeDispatcher { contract_address: token }.when_not_paused(),
        array![errors::ENFORCED_PAUSE].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn assert_not_deactivated_reverts_when_deactivated() {
    let token = deactivated_token();
    let mock = IPauseMockSafeDispatcher { contract_address: token };
    assert_reverted_with(mock.when_not_deactivated(), array![errors::ENFORCED_DEACTIVATION].span());
}

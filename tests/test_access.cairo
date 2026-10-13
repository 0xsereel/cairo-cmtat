// SPDX-License-Identifier: MPL-2.0
// CMTATAccessControlComponent: default admin implicitly holds every role.

use cairo_cmtat::errors;
use cairo_cmtat::mocks::access_control_mock::{
    IAccessControlMockDispatcher, IAccessControlMockDispatcherTrait,
    IAccessControlMockSafeDispatcher, IAccessControlMockSafeDispatcherTrait,
};
use cairo_cmtat::roles::{BURNER_ROLE, DEFAULT_ADMIN_ROLE, MINTER_ROLE, PAUSER_ROLE};
use openzeppelin::access::accesscontrol::AccessControlComponent;
use openzeppelin::interfaces::accesscontrol::{
    IACCESSCONTROL_ID, IAccessControlDispatcher, IAccessControlDispatcherTrait,
    IAccessControlSafeDispatcher, IAccessControlSafeDispatcherTrait,
};
use openzeppelin::interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use openzeppelin_testing::{EventSpyExt, spy_events};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address};
use starknet::ContractAddress;
use crate::utils::{ADMIN, MINTER, OTHER, ZERO, assert_reverted_with};

const ARBITRARY_ROLE: felt252 = 'ARBITRARY_ROLE';

fn deploy() -> ContractAddress {
    openzeppelin_testing::declare_and_deploy("AccessControlMock", array![ADMIN.into()])
}

fn setup() -> (ContractAddress, IAccessControlDispatcher) {
    let token = deploy();
    (token, IAccessControlDispatcher { contract_address: token })
}

fn grant(token: ContractAddress, role: felt252, account: ContractAddress) {
    start_cheat_caller_address(token, ADMIN);
    IAccessControlDispatcher { contract_address: token }.grant_role(role, account);
}

//
// initializer
//

#[test]
fn initializer_grants_default_admin() {
    let (_, access) = setup();
    assert!(access.has_role(DEFAULT_ADMIN_ROLE, ADMIN));
    assert!(!access.has_role(DEFAULT_ADMIN_ROLE, OTHER));
}

#[test]
fn initializer_registers_access_control_interface() {
    let (token, _) = setup();
    assert!(ISRC5Dispatcher { contract_address: token }.supports_interface(IACCESSCONTROL_ID));
}

#[test]
fn initializer_rejects_zero_admin() {
    let class = declare("AccessControlMock").unwrap().contract_class();
    match class.deploy(@array![ZERO.into()]) {
        Result::Ok(_) => panic!("Expected deploy to fail"),
        Result::Err(panic_data) => assert_eq!(
            panic_data, array![errors::ACCESS_CONTROL_ADDRESS_ZERO],
        ),
    }
}

//
// has_role
//

#[test]
fn admin_implicitly_holds_every_role() {
    let (_, access) = setup();
    assert!(access.has_role(MINTER_ROLE, ADMIN));
    assert!(access.has_role(PAUSER_ROLE, ADMIN));
    assert!(access.has_role(ARBITRARY_ROLE, ADMIN));
}

#[test]
fn non_admin_holds_only_granted_roles() {
    let (token, access) = setup();
    grant(token, MINTER_ROLE, MINTER);
    assert!(access.has_role(MINTER_ROLE, MINTER));
    assert!(!access.has_role(BURNER_ROLE, MINTER));
    assert!(!access.has_role(DEFAULT_ADMIN_ROLE, MINTER));
}

#[test]
fn revoking_admin_removes_implicit_roles() {
    let (token, access) = setup();
    grant(token, DEFAULT_ADMIN_ROLE, OTHER);
    start_cheat_caller_address(token, OTHER);
    access.revoke_role(DEFAULT_ADMIN_ROLE, ADMIN);
    assert!(!access.has_role(MINTER_ROLE, ADMIN));
    assert!(!access.has_role(DEFAULT_ADMIN_ROLE, ADMIN));
}

//
// assert_only_role
//

#[test]
fn assert_only_role_allows_admin() {
    let token = deploy();
    start_cheat_caller_address(token, ADMIN);
    assert!(IAccessControlMockDispatcher { contract_address: token }.only_minter());
}

#[test]
fn assert_only_role_allows_role_holder() {
    let token = deploy();
    grant(token, MINTER_ROLE, MINTER);
    start_cheat_caller_address(token, MINTER);
    assert!(IAccessControlMockDispatcher { contract_address: token }.only_minter());
}

#[test]
#[feature("safe_dispatcher")]
fn assert_only_role_rejects_others() {
    let token = deploy();
    grant(token, BURNER_ROLE, OTHER);
    start_cheat_caller_address(token, OTHER);
    assert_reverted_with(
        IAccessControlMockSafeDispatcher { contract_address: token }.only_minter(),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

//
// grant / revoke / renounce
//

#[test]
fn grant_role_emits_event() {
    let (token, access) = setup();
    let mut spy = spy_events();
    start_cheat_caller_address(token, ADMIN);
    access.grant_role(MINTER_ROLE, MINTER);
    spy
        .assert_only_event(
            token,
            AccessControlComponent::Event::RoleGranted(
                AccessControlComponent::RoleGranted {
                    role: MINTER_ROLE, account: MINTER, sender: ADMIN,
                },
            ),
        );
}

#[test]
#[feature("safe_dispatcher")]
fn grant_role_requires_role_admin() {
    let token = deploy();
    grant(token, MINTER_ROLE, MINTER);
    start_cheat_caller_address(token, MINTER);
    assert_reverted_with(
        IAccessControlSafeDispatcher { contract_address: token }.grant_role(MINTER_ROLE, OTHER),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

#[test]
fn revoke_role_removes_role() {
    let (token, access) = setup();
    grant(token, MINTER_ROLE, MINTER);
    access.revoke_role(MINTER_ROLE, MINTER);
    assert!(!access.has_role(MINTER_ROLE, MINTER));
}

#[test]
#[feature("safe_dispatcher")]
fn revoke_role_requires_role_admin() {
    let token = deploy();
    grant(token, MINTER_ROLE, MINTER);
    start_cheat_caller_address(token, OTHER);
    assert_reverted_with(
        IAccessControlSafeDispatcher { contract_address: token }.revoke_role(MINTER_ROLE, MINTER),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

#[test]
fn renounce_role_removes_own_role() {
    let (token, access) = setup();
    grant(token, MINTER_ROLE, MINTER);
    start_cheat_caller_address(token, MINTER);
    access.renounce_role(MINTER_ROLE, MINTER);
    assert!(!access.has_role(MINTER_ROLE, MINTER));
}

#[test]
#[feature("safe_dispatcher")]
fn renounce_role_rejects_other_account() {
    let token = deploy();
    grant(token, MINTER_ROLE, MINTER);
    start_cheat_caller_address(token, ADMIN);
    assert_reverted_with(
        IAccessControlSafeDispatcher { contract_address: token }.renounce_role(MINTER_ROLE, MINTER),
        array![AccessControlComponent::Errors::INVALID_CALLER].span(),
    );
}

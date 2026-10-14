// SPDX-License-Identifier: MPL-2.0
// ERC-1404 messages and the pinned read-vs-revert cases. The per-state codes are
// covered by test_validation_matrix.

use cairo_cmtat::errors;
use cairo_cmtat::interfaces::enforcement::{
    IERC3643EnforcementDispatcher, IERC3643EnforcementDispatcherTrait,
};
use cairo_cmtat::interfaces::erc1404::{
    IERC1404Dispatcher, IERC1404DispatcherTrait, TRANSFER_OK, TRANSFER_REJECTED_DEACTIVATED,
    TRANSFER_REJECTED_FROM_INSUFFICIENT_ACTIVE_BALANCE, TRANSFER_REJECTED_PAUSED,
};
use cairo_cmtat::interfaces::erc20_enforcement::{
    IERC3643ERC20EnforcementDispatcher, IERC3643ERC20EnforcementDispatcherTrait,
    IERC7943FungibleEnforcementDispatcher, IERC7943FungibleEnforcementDispatcherTrait,
};
use cairo_cmtat::interfaces::pause::{
    IERC3643PauseDispatcher, IERC3643PauseDispatcherTrait, IERC8343Dispatcher,
    IERC8343DispatcherTrait,
};
use cairo_cmtat::interfaces::validation::{
    IERC3643ComplianceReadDispatcher, IERC3643ComplianceReadDispatcherTrait,
};
use cairo_cmtat::roles::{ENFORCER_ROLE, ERC20ENFORCER_ROLE, PAUSER_ROLE};
use openzeppelin::interfaces::accesscontrol::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::interfaces::erc20::{
    IERC20Dispatcher, IERC20DispatcherTrait, IERC20SafeDispatcher, IERC20SafeDispatcherTrait,
};
use openzeppelin::utils::serde::SerializedAppend;
use snforge_std::start_cheat_caller_address;
use starknet::ContractAddress;
use crate::utils::{
    ADMIN, ENFORCER, ERC20ENFORCER, HOLDER, PAUSER, RECIPIENT, SUPPLY, ZERO, assert_reverted_with,
};

fn setup() -> ContractAddress {
    let mut calldata = array![];
    calldata.append_serde(18_u8);
    calldata.append_serde(SUPPLY);
    calldata.append_serde(HOLDER);
    calldata.append_serde(ADMIN);
    let token = openzeppelin_testing::declare_and_deploy("CommonMock", calldata);
    start_cheat_caller_address(token, ADMIN);
    let access = IAccessControlDispatcher { contract_address: token };
    access.grant_role(PAUSER_ROLE, PAUSER);
    access.grant_role(ENFORCER_ROLE, ENFORCER);
    access.grant_role(ERC20ENFORCER_ROLE, ERC20ENFORCER);
    token
}

fn erc1404(token: ContractAddress) -> IERC1404Dispatcher {
    IERC1404Dispatcher { contract_address: token }
}

fn can_transfer(token: ContractAddress, from: ContractAddress, to: ContractAddress) -> bool {
    IERC3643ComplianceReadDispatcher { contract_address: token }.can_transfer(from, to, 1)
}

fn pause(token: ContractAddress) {
    start_cheat_caller_address(token, PAUSER);
    IERC3643PauseDispatcher { contract_address: token }.pause();
}

fn deactivate(token: ContractAddress) {
    pause(token);
    start_cheat_caller_address(token, ADMIN);
    IERC8343Dispatcher { contract_address: token }.deactivate_contract();
}

#[feature("safe_dispatcher")]
fn transfer_as_holder(token: ContractAddress, value: u256) -> Result<bool, Array<felt252>> {
    start_cheat_caller_address(token, HOLDER);
    IERC20SafeDispatcher { contract_address: token }.transfer(RECIPIENT, value)
}

//
// Messages
//

#[test]
fn messages_match_cmtat() {
    let token = setup();
    let e = erc1404(token);
    assert_eq!(e.message_for_transfer_restriction(0), "NoRestriction");
    assert_eq!(e.message_for_transfer_restriction(1), "ContractDeactivated");
    assert_eq!(e.message_for_transfer_restriction(2), "EnforcedPause");
    assert_eq!(e.message_for_transfer_restriction(3), "AddrFromIsFrozen");
    assert_eq!(e.message_for_transfer_restriction(4), "AddrToIsFrozen");
    assert_eq!(e.message_for_transfer_restriction(5), "AddrSpenderIsFrozen");
    assert_eq!(e.message_for_transfer_restriction(6), "AddrFrom:insufficientActiveBalance");
    assert_eq!(e.message_for_transfer_restriction(7), "UnknownCode");
    assert_eq!(e.message_for_transfer_restriction(255), "UnknownCode");
}

//
// Pinned: read and revert paths
//

/// Deactivated: the read path reports 1; the transfer reverts with the pause error.
#[test]
#[feature("safe_dispatcher")]
fn deactivated_code_1_but_transfer_reverts_with_pause() {
    let token = setup();
    deactivate(token);
    assert_eq!(
        erc1404(token).detect_transfer_restriction(HOLDER, RECIPIENT, 1),
        TRANSFER_REJECTED_DEACTIVATED,
    );
    assert_reverted_with(transfer_as_holder(token, 1), array![errors::ENFORCED_PAUSE].span());
}

/// Paused with a short free balance: both paths report the active balance first.
#[test]
#[feature("safe_dispatcher")]
fn paused_and_short_free_balance_code_6_and_insufficient_unfrozen() {
    let token = setup();
    start_cheat_caller_address(token, ERC20ENFORCER);
    IERC3643ERC20EnforcementDispatcher { contract_address: token }
        .freeze_partial_tokens(HOLDER, SUPPLY);
    pause(token);
    assert_eq!(
        erc1404(token).detect_transfer_restriction(HOLDER, RECIPIENT, 1),
        TRANSFER_REJECTED_FROM_INSUFFICIENT_ACTIVE_BALANCE,
    );
    let mut expected = array![errors::ERC7943_INSUFFICIENT_UNFROZEN_BAL];
    expected.append_serde(HOLDER);
    expected.append_serde(1_u256);
    expected.append_serde(0_u256);
    assert_reverted_with(transfer_as_holder(token, 1), expected.span());
}

/// A zero-value transfer always passes the active-balance check, on both paths.
#[test]
fn zero_value_with_fully_frozen_balance_is_allowed() {
    let token = setup();
    start_cheat_caller_address(token, ERC20ENFORCER);
    IERC7943FungibleEnforcementDispatcher { contract_address: token }
        .set_frozen_tokens(HOLDER, SUPPLY + 1);
    assert_eq!(erc1404(token).detect_transfer_restriction(HOLDER, RECIPIENT, 0), TRANSFER_OK);
    start_cheat_caller_address(token, HOLDER);
    assert!(IERC20Dispatcher { contract_address: token }.transfer(RECIPIENT, 0));
}

/// Paused zero-value transfer: both paths reject it (code 2, pause revert).
#[test]
#[feature("safe_dispatcher")]
fn zero_value_while_paused_is_rejected_on_both_paths() {
    let token = setup();
    pause(token);
    assert_eq!(
        erc1404(token).detect_transfer_restriction(HOLDER, RECIPIENT, 0), TRANSFER_REJECTED_PAUSED,
    );
    assert_reverted_with(transfer_as_holder(token, 0), array![errors::ENFORCED_PAUSE].span());
}

//
// can_transfer on mint and burn shapes (from or to zero)
//

#[test]
fn can_transfer_mint_and_burn_ignore_pause() {
    let token = setup();
    pause(token);
    assert!(can_transfer(token, ZERO, RECIPIENT));
    assert!(can_transfer(token, HOLDER, ZERO));
    assert!(!can_transfer(token, HOLDER, RECIPIENT));
}

#[test]
fn can_transfer_mint_and_burn_respect_deactivation_and_freeze() {
    let token = setup();
    start_cheat_caller_address(token, ENFORCER);
    let enforcement = IERC3643EnforcementDispatcher { contract_address: token };
    enforcement.set_address_frozen(RECIPIENT, true);
    enforcement.set_address_frozen(HOLDER, true);
    assert!(!can_transfer(token, ZERO, RECIPIENT));
    assert!(!can_transfer(token, HOLDER, ZERO));
    enforcement.set_address_frozen(RECIPIENT, false);
    enforcement.set_address_frozen(HOLDER, false);
    deactivate(token);
    assert!(!can_transfer(token, ZERO, RECIPIENT));
    assert!(!can_transfer(token, HOLDER, ZERO));
}

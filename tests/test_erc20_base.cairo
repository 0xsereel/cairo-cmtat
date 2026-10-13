// SPDX-License-Identifier: MPL-2.0
// ERC20BaseComponent with the CMTATBaseCommon check chain.

use cairo_cmtat::components::erc20_base::ERC20BaseComponent;
use cairo_cmtat::errors;
use cairo_cmtat::interfaces::enforcement::{
    IERC3643EnforcementDispatcher, IERC3643EnforcementDispatcherTrait,
};
use cairo_cmtat::interfaces::erc20_base::{
    IERC20BatchBalanceDispatcher, IERC20BatchBalanceDispatcherTrait,
};
use cairo_cmtat::interfaces::erc20_enforcement::{
    IERC3643ERC20EnforcementDispatcher, IERC3643ERC20EnforcementDispatcherTrait,
};
use cairo_cmtat::interfaces::pause::{
    IERC3643PauseDispatcher, IERC3643PauseDispatcherTrait, IERC8343Dispatcher,
    IERC8343DispatcherTrait,
};
use cairo_cmtat::roles::{ENFORCER_ROLE, ERC20ENFORCER_ROLE, PAUSER_ROLE};
use core::num::traits::Bounded;
use openzeppelin::interfaces::accesscontrol::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::interfaces::erc20::{
    IERC20CamelOnlyDispatcher, IERC20CamelOnlyDispatcherTrait, IERC20Dispatcher,
    IERC20DispatcherTrait, IERC20MetadataDispatcher, IERC20MetadataDispatcherTrait,
    IERC20SafeDispatcher, IERC20SafeDispatcherTrait,
};
use openzeppelin::token::erc20::ERC20Component;
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin_testing::{EventSpyExt, spy_events};
use snforge_std::start_cheat_caller_address;
use starknet::ContractAddress;
use crate::utils::{
    ADMIN, ENFORCER, ERC20ENFORCER, HOLDER, OTHER, PAUSER, RECIPIENT, SPENDER, SUPPLY,
    assert_reverted_with,
};

const DECIMALS: u8 = 6;
const FROZEN: u256 = 500;
const ACTIVE: u256 = SUPPLY - FROZEN;

fn setup() -> ContractAddress {
    let mut calldata = array![];
    calldata.append_serde(DECIMALS);
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

fn erc20(token: ContractAddress) -> IERC20Dispatcher {
    IERC20Dispatcher { contract_address: token }
}

fn safe_erc20(token: ContractAddress) -> IERC20SafeDispatcher {
    IERC20SafeDispatcher { contract_address: token }
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

fn freeze(token: ContractAddress, account: ContractAddress) {
    start_cheat_caller_address(token, ENFORCER);
    IERC3643EnforcementDispatcher { contract_address: token }.set_address_frozen(account, true);
}

fn freeze_partial(token: ContractAddress, account: ContractAddress, value: u256) {
    start_cheat_caller_address(token, ERC20ENFORCER);
    IERC3643ERC20EnforcementDispatcher { contract_address: token }
        .freeze_partial_tokens(account, value);
}

fn approve(token: ContractAddress, owner: ContractAddress, spender: ContractAddress, value: u256) {
    start_cheat_caller_address(token, owner);
    erc20(token).approve(spender, value);
}

fn as_caller(token: ContractAddress, caller: ContractAddress) -> IERC20SafeDispatcher {
    start_cheat_caller_address(token, caller);
    safe_erc20(token)
}

fn cannot_send(account: ContractAddress) -> Span<felt252> {
    array![errors::ERC7943_CANNOT_SEND, account.into()].span()
}

fn cannot_receive(account: ContractAddress) -> Span<felt252> {
    array![errors::ERC7943_CANNOT_RECEIVE, account.into()].span()
}

fn insufficient_unfrozen(account: ContractAddress, value: u256, active: u256) -> Span<felt252> {
    let mut data = array![errors::ERC7943_INSUFFICIENT_UNFROZEN_BAL];
    data.append_serde(account);
    data.append_serde(value);
    data.append_serde(active);
    data.span()
}

fn transfer_event(
    from: ContractAddress, to: ContractAddress, value: u256,
) -> ERC20Component::Event {
    ERC20Component::Event::Transfer(ERC20Component::Transfer { from, to, value })
}

//
// Metadata and reads
//

#[test]
fn metadata_uses_initialized_decimals() {
    let token = setup();
    let metadata = IERC20MetadataDispatcher { contract_address: token };
    assert_eq!(metadata.name(), "Mock");
    assert_eq!(metadata.symbol(), "MCK");
    assert_eq!(metadata.decimals(), DECIMALS);
}

#[test]
fn batch_balance_of_returns_balances_and_total_supply() {
    let token = setup();
    start_cheat_caller_address(token, HOLDER);
    erc20(token).transfer(RECIPIENT, 100);
    let (balances, total_supply) = IERC20BatchBalanceDispatcher { contract_address: token }
        .batch_balance_of(array![HOLDER, RECIPIENT, OTHER].span());
    assert_eq!(balances, array![SUPPLY - 100, 100, 0]);
    assert_eq!(total_supply, SUPPLY);
}

#[test]
fn camel_case_reads_and_transfer_from() {
    let token = setup();
    approve(token, HOLDER, SPENDER, 100);
    start_cheat_caller_address(token, SPENDER);
    let camel = IERC20CamelOnlyDispatcher { contract_address: token };
    assert!(camel.transferFrom(HOLDER, RECIPIENT, 100));
    assert_eq!(camel.balanceOf(RECIPIENT), 100);
    assert_eq!(camel.totalSupply(), SUPPLY);
}

//
// transfer / transfer_from
//

#[test]
fn transfer_moves_balance_and_emits_transfer_only() {
    let token = setup();
    start_cheat_caller_address(token, HOLDER);
    let mut spy = spy_events();
    assert!(erc20(token).transfer(RECIPIENT, 100));
    assert_eq!(erc20(token).balance_of(RECIPIENT), 100);
    spy.assert_only_event(token, transfer_event(HOLDER, RECIPIENT, 100));
}

#[test]
fn transfer_from_spends_allowance_and_emits_spend_without_approval() {
    let token = setup();
    approve(token, HOLDER, SPENDER, 150);
    start_cheat_caller_address(token, SPENDER);
    let mut spy = spy_events();
    assert!(erc20(token).transfer_from(HOLDER, RECIPIENT, 100));
    assert_eq!(erc20(token).allowance(HOLDER, SPENDER), 50);
    assert_eq!(erc20(token).balance_of(RECIPIENT), 100);
    spy.assert_emitted_single(token, transfer_event(HOLDER, RECIPIENT, 100));
    spy
        .assert_only_event(
            token,
            ERC20BaseComponent::Event::Spend(
                ERC20BaseComponent::Spend { account: HOLDER, spender: SPENDER, value: 100 },
            ),
        );
}

#[test]
fn transfer_from_keeps_infinite_allowance() {
    let token = setup();
    approve(token, HOLDER, SPENDER, Bounded::MAX);
    start_cheat_caller_address(token, SPENDER);
    erc20(token).transfer_from(HOLDER, RECIPIENT, 100);
    assert_eq!(erc20(token).allowance(HOLDER, SPENDER), Bounded::MAX);
}

#[test]
#[feature("safe_dispatcher")]
fn transfer_from_rejects_insufficient_allowance() {
    let token = setup();
    approve(token, HOLDER, SPENDER, 99);
    assert_reverted_with(
        as_caller(token, SPENDER).transfer_from(HOLDER, RECIPIENT, 100),
        array![ERC20Component::Errors::INSUFFICIENT_ALLOWANCE].span(),
    );
}

//
// Pause and deactivation
//

#[test]
#[feature("safe_dispatcher")]
fn transfer_reverts_when_paused() {
    let token = setup();
    pause(token);
    assert_reverted_with(
        as_caller(token, HOLDER).transfer(RECIPIENT, 1), array![errors::ENFORCED_PAUSE].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn transfer_from_reverts_when_paused() {
    let token = setup();
    approve(token, HOLDER, SPENDER, 100);
    pause(token);
    assert_reverted_with(
        as_caller(token, SPENDER).transfer_from(HOLDER, RECIPIENT, 1),
        array![errors::ENFORCED_PAUSE].span(),
    );
}

/// Deactivation is not checked on transfers: a deactivated token is paused.
#[test]
#[feature("safe_dispatcher")]
fn transfer_on_deactivated_token_reverts_with_pause_error() {
    let token = setup();
    deactivate(token);
    assert_reverted_with(
        as_caller(token, HOLDER).transfer(RECIPIENT, 1), array![errors::ENFORCED_PAUSE].span(),
    );
}

//
// Address freeze, in CMTAT order: spender, from, to
//

#[test]
#[feature("safe_dispatcher")]
fn transfer_reverts_when_sender_frozen() {
    let token = setup();
    freeze(token, HOLDER);
    assert_reverted_with(as_caller(token, HOLDER).transfer(RECIPIENT, 1), cannot_send(HOLDER));
}

#[test]
#[feature("safe_dispatcher")]
fn transfer_reverts_when_recipient_frozen() {
    let token = setup();
    freeze(token, RECIPIENT);
    assert_reverted_with(
        as_caller(token, HOLDER).transfer(RECIPIENT, 1), cannot_receive(RECIPIENT),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn transfer_from_reverts_when_spender_frozen() {
    let token = setup();
    approve(token, HOLDER, SPENDER, 100);
    freeze(token, SPENDER);
    assert_reverted_with(
        as_caller(token, SPENDER).transfer_from(HOLDER, RECIPIENT, 1), cannot_send(SPENDER),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn freeze_errors_follow_spender_from_to_order() {
    let token = setup();
    approve(token, HOLDER, SPENDER, 100);
    freeze(token, RECIPIENT);
    freeze(token, HOLDER);
    assert_reverted_with(
        as_caller(token, SPENDER).transfer_from(HOLDER, RECIPIENT, 1), cannot_send(HOLDER),
    );
    freeze(token, SPENDER);
    assert_reverted_with(
        as_caller(token, SPENDER).transfer_from(HOLDER, RECIPIENT, 1), cannot_send(SPENDER),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn pause_is_checked_before_freeze() {
    let token = setup();
    freeze(token, HOLDER);
    pause(token);
    assert_reverted_with(
        as_caller(token, HOLDER).transfer(RECIPIENT, 1), array![errors::ENFORCED_PAUSE].span(),
    );
}

//
// Partial freeze: active balance is checked first
//

#[test]
fn transfer_up_to_active_balance_succeeds() {
    let token = setup();
    freeze_partial(token, HOLDER, FROZEN);
    start_cheat_caller_address(token, HOLDER);
    erc20(token).transfer(RECIPIENT, ACTIVE);
    assert_eq!(erc20(token).balance_of(RECIPIENT), ACTIVE);
}

#[test]
#[feature("safe_dispatcher")]
fn transfer_above_active_balance_reverts() {
    let token = setup();
    freeze_partial(token, HOLDER, FROZEN);
    assert_reverted_with(
        as_caller(token, HOLDER).transfer(RECIPIENT, ACTIVE + 1),
        insufficient_unfrozen(HOLDER, ACTIVE + 1, ACTIVE),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn transfer_from_above_active_balance_reverts() {
    let token = setup();
    approve(token, HOLDER, SPENDER, SUPPLY);
    freeze_partial(token, HOLDER, FROZEN);
    assert_reverted_with(
        as_caller(token, SPENDER).transfer_from(HOLDER, RECIPIENT, ACTIVE + 1),
        insufficient_unfrozen(HOLDER, ACTIVE + 1, ACTIVE),
    );
}

/// CMTATBaseCommon runs the active-balance check before pause and freeze.
#[test]
#[feature("safe_dispatcher")]
fn active_balance_is_checked_before_pause_and_freeze() {
    let token = setup();
    freeze_partial(token, HOLDER, FROZEN);
    freeze(token, HOLDER);
    pause(token);
    assert_reverted_with(
        as_caller(token, HOLDER).transfer(RECIPIENT, ACTIVE + 1),
        insufficient_unfrozen(HOLDER, ACTIVE + 1, ACTIVE),
    );
    assert_reverted_with(
        as_caller(token, HOLDER).transfer(RECIPIENT, ACTIVE), array![errors::ENFORCED_PAUSE].span(),
    );
}

/// Without frozen tokens the active-balance check passes and ERC-20 reports the
/// shortfall after the module checks.
#[test]
#[feature("safe_dispatcher")]
fn plain_insufficient_balance_reverts_after_module_checks() {
    let token = setup();
    pause(token);
    assert_reverted_with(
        as_caller(token, HOLDER).transfer(RECIPIENT, SUPPLY + 1),
        array![errors::ENFORCED_PAUSE].span(),
    );
}

//
// approve (ValidationModuleAllowance)
//

#[test]
fn approve_zero_is_always_allowed() {
    let token = setup();
    approve(token, HOLDER, SPENDER, 100);
    freeze(token, HOLDER);
    freeze(token, SPENDER);
    pause(token);
    approve(token, HOLDER, SPENDER, 0);
    assert_eq!(erc20(token).allowance(HOLDER, SPENDER), 0);
}

#[test]
#[feature("safe_dispatcher")]
fn approve_reverts_when_paused() {
    let token = setup();
    pause(token);
    assert_reverted_with(
        as_caller(token, HOLDER).approve(SPENDER, 1), array![errors::ENFORCED_PAUSE].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn approve_reverts_when_owner_frozen() {
    let token = setup();
    freeze(token, HOLDER);
    assert_reverted_with(as_caller(token, HOLDER).approve(SPENDER, 1), cannot_send(HOLDER));
}

#[test]
#[feature("safe_dispatcher")]
fn approve_reverts_when_spender_frozen() {
    let token = setup();
    freeze(token, SPENDER);
    assert_reverted_with(as_caller(token, HOLDER).approve(SPENDER, 1), cannot_send(SPENDER));
}

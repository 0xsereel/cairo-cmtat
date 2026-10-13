// SPDX-License-Identifier: MPL-2.0
// ERC20EnforcementComponent: partial freeze, active balance and forced transfer.

use cairo_cmtat::components::erc20_base::ERC20BaseComponent;
use cairo_cmtat::components::erc20_enforcement::ERC20EnforcementComponent;
use cairo_cmtat::errors;
use cairo_cmtat::interfaces::erc20_enforcement::{
    IERC3643ERC20EnforcementDispatcher, IERC3643ERC20EnforcementDispatcherTrait,
    IERC3643ERC20EnforcementSafeDispatcher, IERC3643ERC20EnforcementSafeDispatcherTrait,
    IERC7551ERC20EnforcementDispatcher, IERC7551ERC20EnforcementDispatcherTrait,
    IERC7943FungibleEnforcementDispatcher, IERC7943FungibleEnforcementDispatcherTrait,
    IERC7943FungibleEnforcementSafeDispatcher, IERC7943FungibleEnforcementSafeDispatcherTrait,
};
use cairo_cmtat::mocks::erc20_enforcement_mock::{
    IERC20EnforcementMockDispatcher, IERC20EnforcementMockDispatcherTrait,
    IERC20EnforcementMockSafeDispatcher, IERC20EnforcementMockSafeDispatcherTrait,
};
use cairo_cmtat::roles::ERC20ENFORCER_ROLE;
use core::num::traits::Bounded;
use openzeppelin::access::accesscontrol::AccessControlComponent;
use openzeppelin::interfaces::accesscontrol::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::token::erc20::ERC20Component;
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin_testing::{EventSpyExt, spy_events};
use snforge_std::start_cheat_caller_address;
use starknet::ContractAddress;
use crate::utils::{
    ADMIN, ERC20ENFORCER, HOLDER, OTHER, RECIPIENT, SUPPLY, ZERO, assert_reverted_with,
};

const FROZEN: u256 = 500;

fn setup() -> ContractAddress {
    let mut calldata = array![];
    calldata.append_serde(SUPPLY);
    calldata.append_serde(HOLDER);
    calldata.append_serde(ADMIN);
    let token = openzeppelin_testing::declare_and_deploy("ERC20EnforcementMock", calldata);
    start_cheat_caller_address(token, ADMIN);
    IAccessControlDispatcher { contract_address: token }
        .grant_role(ERC20ENFORCER_ROLE, ERC20ENFORCER);
    start_cheat_caller_address(token, ERC20ENFORCER);
    token
}

/// Token with `FROZEN` of HOLDER's `SUPPLY` frozen; caller is ADMIN.
fn setup_frozen() -> ContractAddress {
    let token = setup();
    erc3643(token).freeze_partial_tokens(HOLDER, FROZEN);
    start_cheat_caller_address(token, ADMIN);
    token
}

fn erc3643(token: ContractAddress) -> IERC3643ERC20EnforcementDispatcher {
    IERC3643ERC20EnforcementDispatcher { contract_address: token }
}

fn erc7943(token: ContractAddress) -> IERC7943FungibleEnforcementDispatcher {
    IERC7943FungibleEnforcementDispatcher { contract_address: token }
}

fn erc7551(token: ContractAddress) -> IERC7551ERC20EnforcementDispatcher {
    IERC7551ERC20EnforcementDispatcher { contract_address: token }
}

fn erc20(token: ContractAddress) -> IERC20Dispatcher {
    IERC20Dispatcher { contract_address: token }
}

fn frozen_event(account: ContractAddress, amount: u256) -> ERC20EnforcementComponent::Event {
    ERC20EnforcementComponent::Event::Frozen(ERC20EnforcementComponent::Frozen { account, amount })
}

fn tokens_frozen_event(
    account: ContractAddress, value: u256, data: Span<felt252>,
) -> ERC20EnforcementComponent::Event {
    ERC20EnforcementComponent::Event::TokensFrozen(
        ERC20EnforcementComponent::TokensFrozen { account, value, data },
    )
}

fn tokens_unfrozen_event(
    account: ContractAddress, value: u256, data: Span<felt252>,
) -> ERC20EnforcementComponent::Event {
    ERC20EnforcementComponent::Event::TokensUnfrozen(
        ERC20EnforcementComponent::TokensUnfrozen { account, value, data },
    )
}

fn forced_transfer_event(
    from: ContractAddress, to: ContractAddress, value: u256, data: Span<felt252>,
) -> ERC20EnforcementComponent::Event {
    ERC20EnforcementComponent::Event::ForcedTransfer(
        ERC20EnforcementComponent::ForcedTransfer { operator: ADMIN, from, to, value, data },
    )
}

fn transfer_event(
    from: ContractAddress, to: ContractAddress, value: u256,
) -> ERC20Component::Event {
    ERC20Component::Event::Transfer(ERC20Component::Transfer { from, to, value })
}

//
// freeze_partial_tokens
//

#[test]
fn freeze_partial_tokens_accumulates_and_emits() {
    let token = setup();
    erc3643(token).freeze_partial_tokens(HOLDER, 100);
    let mut spy = spy_events();
    erc3643(token).freeze_partial_tokens(HOLDER, 50);
    assert_eq!(erc7943(token).get_frozen_tokens(HOLDER), 150);
    spy.assert_emitted_single(token, frozen_event(HOLDER, 150));
    spy.assert_only_event(token, tokens_frozen_event(HOLDER, 50, array![].span()));
}

#[test]
fn freeze_partial_tokens_up_to_balance() {
    let token = setup();
    erc3643(token).freeze_partial_tokens(HOLDER, SUPPLY);
    assert_eq!(erc7551(token).get_active_balance_of(HOLDER), 0);
}

#[test]
#[feature("safe_dispatcher")]
fn freeze_partial_tokens_rejects_exceeding_balance() {
    let token = setup();
    erc3643(token).freeze_partial_tokens(HOLDER, SUPPLY - 1);
    assert_reverted_with(
        IERC3643ERC20EnforcementSafeDispatcher { contract_address: token }
            .freeze_partial_tokens(HOLDER, 2),
        array![errors::ERC20ENF_VALUE_EXCEEDS_AVAIL_BAL].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn freeze_partial_tokens_rejects_zero_address() {
    let token = setup();
    assert_reverted_with(
        IERC3643ERC20EnforcementSafeDispatcher { contract_address: token }
            .freeze_partial_tokens(ZERO, 0),
        array![errors::ERC20ENF_ZERO_ADDRESS_NOT_ALLOWED].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn freeze_partial_tokens_requires_erc20_enforcer() {
    let token = setup();
    start_cheat_caller_address(token, OTHER);
    assert_reverted_with(
        IERC3643ERC20EnforcementSafeDispatcher { contract_address: token }
            .freeze_partial_tokens(HOLDER, 1),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

#[test]
fn freeze_partial_tokens_with_data_emits_data() {
    let token = setup();
    let data = array!['court order'].span();
    let mut spy = spy_events();
    erc7551(token).freeze_partial_tokens_with_data(HOLDER, 100, data);
    spy.assert_emitted_single(token, frozen_event(HOLDER, 100));
    spy.assert_only_event(token, tokens_frozen_event(HOLDER, 100, data));
}

//
// unfreeze_partial_tokens
//

#[test]
fn unfreeze_partial_tokens_reduces_and_emits() {
    let token = setup();
    erc3643(token).freeze_partial_tokens(HOLDER, FROZEN);
    let mut spy = spy_events();
    erc3643(token).unfreeze_partial_tokens(HOLDER, 200);
    assert_eq!(erc7943(token).get_frozen_tokens(HOLDER), FROZEN - 200);
    spy.assert_emitted_single(token, frozen_event(HOLDER, FROZEN - 200));
    spy.assert_only_event(token, tokens_unfrozen_event(HOLDER, 200, array![].span()));
}

#[test]
#[feature("safe_dispatcher")]
fn unfreeze_partial_tokens_rejects_exceeding_frozen() {
    let token = setup();
    erc3643(token).freeze_partial_tokens(HOLDER, FROZEN);
    assert_reverted_with(
        IERC3643ERC20EnforcementSafeDispatcher { contract_address: token }
            .unfreeze_partial_tokens(HOLDER, FROZEN + 1),
        array![errors::ERC20ENF_VALUE_EXCEEDS_FROZEN_BAL].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn unfreeze_partial_tokens_rejects_zero_address() {
    let token = setup();
    assert_reverted_with(
        IERC3643ERC20EnforcementSafeDispatcher { contract_address: token }
            .unfreeze_partial_tokens(ZERO, 0),
        array![errors::ERC20ENF_ZERO_ADDRESS_NOT_ALLOWED].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn unfreeze_partial_tokens_requires_erc20_enforcer() {
    let token = setup();
    start_cheat_caller_address(token, OTHER);
    assert_reverted_with(
        IERC3643ERC20EnforcementSafeDispatcher { contract_address: token }
            .unfreeze_partial_tokens(HOLDER, 0),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

#[test]
fn unfreeze_partial_tokens_with_data_emits_data() {
    let token = setup();
    erc3643(token).freeze_partial_tokens(HOLDER, FROZEN);
    let data = array!['released'].span();
    let mut spy = spy_events();
    erc7551(token).unfreeze_partial_tokens_with_data(HOLDER, FROZEN, data);
    spy.assert_emitted_single(token, frozen_event(HOLDER, 0));
    spy.assert_only_event(token, tokens_unfrozen_event(HOLDER, FROZEN, data));
}

//
// set_frozen_tokens
//

#[test]
fn set_frozen_tokens_increase_emits_difference() {
    let token = setup();
    erc3643(token).freeze_partial_tokens(HOLDER, 100);
    let mut spy = spy_events();
    assert!(erc7943(token).set_frozen_tokens(HOLDER, 400));
    assert_eq!(erc7943(token).get_frozen_tokens(HOLDER), 400);
    spy.assert_emitted_single(token, frozen_event(HOLDER, 400));
    spy.assert_only_event(token, tokens_frozen_event(HOLDER, 300, array![].span()));
}

#[test]
fn set_frozen_tokens_decrease_emits_difference() {
    let token = setup();
    erc3643(token).freeze_partial_tokens(HOLDER, 400);
    let mut spy = spy_events();
    erc7943(token).set_frozen_tokens(HOLDER, 100);
    spy.assert_emitted_single(token, frozen_event(HOLDER, 100));
    spy.assert_only_event(token, tokens_unfrozen_event(HOLDER, 300, array![].span()));
}

#[test]
fn set_frozen_tokens_may_exceed_balance() {
    let token = setup();
    erc7943(token).set_frozen_tokens(OTHER, 1000);
    assert_eq!(erc7943(token).get_frozen_tokens(OTHER), 1000);
    assert_eq!(erc7551(token).get_active_balance_of(OTHER), 0);
}

#[test]
#[feature("safe_dispatcher")]
fn set_frozen_tokens_rejects_same_value() {
    let token = setup();
    assert_reverted_with(
        IERC7943FungibleEnforcementSafeDispatcher { contract_address: token }
            .set_frozen_tokens(HOLDER, 0),
        array![errors::ERC20ENF_VALUE_EQ_CURRENT_FROZEN].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn set_frozen_tokens_rejects_zero_address() {
    let token = setup();
    assert_reverted_with(
        IERC7943FungibleEnforcementSafeDispatcher { contract_address: token }
            .set_frozen_tokens(ZERO, 1),
        array![errors::ERC20ENF_ZERO_ADDRESS_NOT_ALLOWED].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn set_frozen_tokens_requires_erc20_enforcer() {
    let token = setup();
    start_cheat_caller_address(token, OTHER);
    assert_reverted_with(
        IERC7943FungibleEnforcementSafeDispatcher { contract_address: token }
            .set_frozen_tokens(HOLDER, 1),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

//
// active balance
//

#[test]
fn active_balance_is_balance_minus_frozen() {
    let token = setup_frozen();
    assert_eq!(erc7551(token).get_active_balance_of(HOLDER), SUPPLY - FROZEN);
}

#[test]
fn check_active_balance_passes_within_active() {
    let token = setup_frozen();
    let mock = IERC20EnforcementMockDispatcher { contract_address: token };
    assert!(mock.check_active_balance(HOLDER, SUPPLY - FROZEN));
    assert!(mock.check_active_balance(OTHER, 0));
}

#[test]
#[feature("safe_dispatcher")]
fn check_active_balance_reverts_with_amounts() {
    let token = setup_frozen();
    let mut expected = array![errors::ERC7943_INSUFFICIENT_UNFROZEN_BAL];
    expected.append_serde(HOLDER);
    expected.append_serde(SUPPLY - FROZEN + 1);
    expected.append_serde(SUPPLY - FROZEN);
    assert_reverted_with(
        IERC20EnforcementMockSafeDispatcher { contract_address: token }
            .check_active_balance(HOLDER, SUPPLY - FROZEN + 1),
        expected.span(),
    );
}

#[test]
fn check_active_balance_allows_zero_when_fully_frozen() {
    let token = setup();
    erc7943(token).set_frozen_tokens(HOLDER, SUPPLY + 1);
    assert!(
        IERC20EnforcementMockDispatcher { contract_address: token }.check_active_balance(HOLDER, 0),
    );
}

//
// forced_transfer
//

#[test]
fn forced_transfer_within_active_balance_keeps_frozen() {
    let token = setup_frozen();
    let mut spy = spy_events();
    assert!(erc7943(token).forced_transfer(HOLDER, RECIPIENT, 100));
    assert_eq!(erc20(token).balance_of(RECIPIENT), 100);
    assert_eq!(erc7943(token).get_frozen_tokens(HOLDER), FROZEN);
    spy.assert_emitted_single(token, transfer_event(HOLDER, RECIPIENT, 100));
    spy.assert_only_event(token, forced_transfer_event(HOLDER, RECIPIENT, 100, array![].span()));
}

#[test]
fn forced_transfer_unfreezes_only_shortfall() {
    let token = setup_frozen();
    let value = SUPPLY - FROZEN + 200;
    let mut spy = spy_events();
    erc7943(token).forced_transfer(HOLDER, RECIPIENT, value);
    assert_eq!(erc20(token).balance_of(RECIPIENT), value);
    assert_eq!(erc7943(token).get_frozen_tokens(HOLDER), FROZEN - 200);
    let empty = array![].span();
    spy.assert_emitted_single(token, frozen_event(HOLDER, FROZEN - 200));
    spy.assert_emitted_single(token, tokens_unfrozen_event(HOLDER, 200, empty));
    spy.assert_emitted_single(token, transfer_event(HOLDER, RECIPIENT, value));
    spy.assert_only_event(token, forced_transfer_event(HOLDER, RECIPIENT, value, empty));
}

#[test]
fn forced_transfer_to_zero_burns() {
    let token = setup_frozen();
    let mut spy = spy_events();
    erc7943(token).forced_transfer(HOLDER, ZERO, SUPPLY);
    assert_eq!(erc20(token).total_supply(), 0);
    assert_eq!(erc20(token).balance_of(HOLDER), 0);
    assert_eq!(erc7943(token).get_frozen_tokens(HOLDER), 0);
    let empty = array![].span();
    spy.assert_emitted_single(token, frozen_event(HOLDER, 0));
    spy.assert_emitted_single(token, tokens_unfrozen_event(HOLDER, FROZEN, empty));
    spy.assert_emitted_single(token, transfer_event(HOLDER, ZERO, SUPPLY));
    spy.assert_only_event(token, forced_transfer_event(HOLDER, ZERO, SUPPLY, empty));
}

#[test]
#[feature("safe_dispatcher")]
fn forced_transfer_to_self_reverts_and_keeps_frozen() {
    let token = setup_frozen();
    assert_reverted_with(
        IERC7943FungibleEnforcementSafeDispatcher { contract_address: token }
            .forced_transfer(HOLDER, HOLDER, SUPPLY),
        array![errors::ERC20ENF_SELF_TRANSFER_NOT_ALLOWED].span(),
    );
    assert_eq!(erc7943(token).get_frozen_tokens(HOLDER), FROZEN);
}

#[test]
#[feature("safe_dispatcher")]
fn forced_transfer_rejects_exceeding_balance() {
    let token = setup_frozen();
    assert_reverted_with(
        IERC7943FungibleEnforcementSafeDispatcher { contract_address: token }
            .forced_transfer(HOLDER, RECIPIENT, SUPPLY + 1),
        array![errors::ERC20ENF_VALUE_EXCEEDS_AVAIL_BAL].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn forced_transfer_requires_default_admin() {
    let token = setup_frozen();
    start_cheat_caller_address(token, ERC20ENFORCER);
    assert_reverted_with(
        IERC7943FungibleEnforcementSafeDispatcher { contract_address: token }
            .forced_transfer(HOLDER, RECIPIENT, 1),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

#[test]
fn forced_transfer_spends_recipient_allowance() {
    let token = setup();
    start_cheat_caller_address(token, HOLDER);
    erc20(token).approve(RECIPIENT, 50);
    start_cheat_caller_address(token, ADMIN);
    let mut spy = spy_events();
    erc7943(token).forced_transfer(HOLDER, RECIPIENT, 30);
    assert_eq!(erc20(token).allowance(HOLDER, RECIPIENT), 20);
    spy
        .assert_emitted_single(
            token,
            ERC20BaseComponent::Event::Spend(
                ERC20BaseComponent::Spend { account: HOLDER, spender: RECIPIENT, value: 30 },
            ),
        );
    spy.assert_emitted_single(token, transfer_event(HOLDER, RECIPIENT, 30));
    spy.assert_only_event(token, forced_transfer_event(HOLDER, RECIPIENT, 30, array![].span()));
}

#[test]
fn forced_transfer_caps_allowance_spend_at_allowance() {
    let token = setup();
    start_cheat_caller_address(token, HOLDER);
    erc20(token).approve(RECIPIENT, 10);
    start_cheat_caller_address(token, ADMIN);
    erc7943(token).forced_transfer(HOLDER, RECIPIENT, 30);
    assert_eq!(erc20(token).allowance(HOLDER, RECIPIENT), 0);
}

#[test]
fn forced_transfer_keeps_infinite_allowance() {
    let token = setup();
    start_cheat_caller_address(token, HOLDER);
    erc20(token).approve(RECIPIENT, Bounded::MAX);
    start_cheat_caller_address(token, ADMIN);
    erc7943(token).forced_transfer(HOLDER, RECIPIENT, 30);
    assert_eq!(erc20(token).allowance(HOLDER, RECIPIENT), Bounded::MAX);
}

#[test]
fn forced_transfer_with_data_carries_data() {
    let token = setup_frozen();
    let data = array!['seizure', 7].span();
    let mut spy = spy_events();
    assert!(erc7551(token).forced_transfer_with_data(HOLDER, RECIPIENT, SUPPLY, data));
    spy.assert_emitted_single(token, frozen_event(HOLDER, 0));
    spy.assert_emitted_single(token, tokens_unfrozen_event(HOLDER, FROZEN, data));
    spy.assert_emitted_single(token, transfer_event(HOLDER, RECIPIENT, SUPPLY));
    spy.assert_only_event(token, forced_transfer_event(HOLDER, RECIPIENT, SUPPLY, data));
}

// SPDX-License-Identifier: MPL-2.0
// BurnComponent with the CMTATBaseCommon check chain.

use cairo_cmtat::components::burn::BurnComponent;
use cairo_cmtat::components::erc20_base::ERC20BaseComponent;
use cairo_cmtat::components::mint::MintComponent;
use cairo_cmtat::errors;
use cairo_cmtat::interfaces::burn::{
    IBurnBatchERC20Dispatcher, IBurnBatchERC20DispatcherTrait, IBurnFromERC20Dispatcher,
    IBurnFromERC20DispatcherTrait, IBurnFromERC20SafeDispatcher, IBurnFromERC20SafeDispatcherTrait,
    IBurnMintERC20Dispatcher, IBurnMintERC20DispatcherTrait, IBurnMintERC20SafeDispatcher,
    IBurnMintERC20SafeDispatcherTrait, IERC3643BurnDispatcher, IERC3643BurnDispatcherTrait,
    IERC3643BurnSafeDispatcher, IERC3643BurnSafeDispatcherTrait, IERC5679BurnDispatcher,
    IERC5679BurnDispatcherTrait,
};
use cairo_cmtat::interfaces::enforcement::{
    IERC3643EnforcementDispatcher, IERC3643EnforcementDispatcherTrait,
};
use cairo_cmtat::interfaces::erc20_enforcement::{
    IERC3643ERC20EnforcementDispatcher, IERC3643ERC20EnforcementDispatcherTrait,
};
use cairo_cmtat::interfaces::pause::{
    IERC3643PauseDispatcher, IERC3643PauseDispatcherTrait, IERC8343Dispatcher,
    IERC8343DispatcherTrait,
};
use cairo_cmtat::roles::{
    BURNER_FROM_ROLE, BURNER_ROLE, BURNER_SELF_ROLE, ENFORCER_ROLE, ERC20ENFORCER_ROLE, MINTER_ROLE,
    PAUSER_ROLE,
};
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
    ADMIN, BURNER, ENFORCER, ERC20ENFORCER, HOLDER, OTHER, PAUSER, RECIPIENT, SUPPLY, ZERO,
    assert_reverted_with,
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
    access.grant_role(BURNER_ROLE, BURNER);
    start_cheat_caller_address(token, BURNER);
    token
}

fn grant(token: ContractAddress, role: felt252, account: ContractAddress) {
    start_cheat_caller_address(token, ADMIN);
    IAccessControlDispatcher { contract_address: token }.grant_role(role, account);
}

fn burn(token: ContractAddress) -> IERC3643BurnDispatcher {
    IERC3643BurnDispatcher { contract_address: token }
}

fn safe_burn(token: ContractAddress) -> IERC3643BurnSafeDispatcher {
    IERC3643BurnSafeDispatcher { contract_address: token }
}

fn erc20(token: ContractAddress) -> IERC20Dispatcher {
    IERC20Dispatcher { contract_address: token }
}

fn pause(token: ContractAddress) {
    start_cheat_caller_address(token, PAUSER);
    IERC3643PauseDispatcher { contract_address: token }.pause();
    start_cheat_caller_address(token, BURNER);
}

fn deactivate(token: ContractAddress) {
    pause(token);
    start_cheat_caller_address(token, ADMIN);
    IERC8343Dispatcher { contract_address: token }.deactivate_contract();
    start_cheat_caller_address(token, BURNER);
}

fn freeze(token: ContractAddress, account: ContractAddress) {
    start_cheat_caller_address(token, ENFORCER);
    IERC3643EnforcementDispatcher { contract_address: token }.set_address_frozen(account, true);
    start_cheat_caller_address(token, BURNER);
}

fn freeze_partial(token: ContractAddress, account: ContractAddress, value: u256) {
    start_cheat_caller_address(token, ERC20ENFORCER);
    IERC3643ERC20EnforcementDispatcher { contract_address: token }
        .freeze_partial_tokens(account, value);
    start_cheat_caller_address(token, BURNER);
}

fn transfer_event(
    from: ContractAddress, to: ContractAddress, value: u256,
) -> ERC20Component::Event {
    ERC20Component::Event::Transfer(ERC20Component::Transfer { from, to, value })
}

fn burn_event(account: ContractAddress, value: u256, data: Span<felt252>) -> BurnComponent::Event {
    BurnComponent::Event::Burn(BurnComponent::Burn { burner: BURNER, account, value, data })
}

fn burn_from_event(
    burner: ContractAddress, account: ContractAddress, value: u256,
) -> BurnComponent::Event {
    BurnComponent::Event::BurnFrom(
        BurnComponent::BurnFrom { burner, account, spender: burner, value },
    )
}

//
// burn
//

#[test]
fn burn_reduces_balance_and_supply() {
    let token = setup();
    let mut spy = spy_events();
    burn(token).burn(HOLDER, 100);
    assert_eq!(erc20(token).balance_of(HOLDER), SUPPLY - 100);
    assert_eq!(erc20(token).total_supply(), SUPPLY - 100);
    spy.assert_emitted_single(token, transfer_event(HOLDER, ZERO, 100));
    spy.assert_only_event(token, burn_event(HOLDER, 100, array![].span()));
}

#[test]
fn burn_with_data_emits_data() {
    let token = setup();
    let data = array!['redemption'].span();
    let mut spy = spy_events();
    IERC5679BurnDispatcher { contract_address: token }.burn_with_data(HOLDER, 100, data);
    spy.assert_emitted_single(token, transfer_event(HOLDER, ZERO, 100));
    spy.assert_only_event(token, burn_event(HOLDER, 100, data));
}

#[test]
#[feature("safe_dispatcher")]
fn burn_requires_burner_role() {
    let token = setup();
    start_cheat_caller_address(token, HOLDER);
    assert_reverted_with(
        safe_burn(token).burn(HOLDER, 1),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

/// Pause does not block burning.
#[test]
fn burn_succeeds_while_paused() {
    let token = setup();
    pause(token);
    burn(token).burn(HOLDER, 100);
    assert_eq!(erc20(token).balance_of(HOLDER), SUPPLY - 100);
}

#[test]
#[feature("safe_dispatcher")]
fn burn_reverts_when_deactivated() {
    let token = setup();
    deactivate(token);
    assert_reverted_with(
        safe_burn(token).burn(HOLDER, 1), array![errors::ENFORCED_DEACTIVATION].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn burn_reverts_when_account_frozen() {
    let token = setup();
    freeze(token, HOLDER);
    assert_reverted_with(
        safe_burn(token).burn(HOLDER, 1), array![errors::ERC7943_CANNOT_SEND, HOLDER.into()].span(),
    );
}

/// The active-balance check applies to burns too, before deactivation and freeze.
#[test]
#[feature("safe_dispatcher")]
fn burn_respects_active_balance_first() {
    let token = setup();
    freeze_partial(token, HOLDER, 500);
    freeze(token, HOLDER);
    let mut expected = array![errors::ERC7943_INSUFFICIENT_UNFROZEN_BAL];
    expected.append_serde(HOLDER);
    expected.append_serde(SUPPLY - 499);
    expected.append_serde(SUPPLY - 500);
    assert_reverted_with(safe_burn(token).burn(HOLDER, SUPPLY - 499), expected.span());
}

//
// batch_burn
//

#[test]
fn batch_burn_emits_batch_event_not_per_account_burn() {
    let token = setup();
    start_cheat_caller_address(token, HOLDER);
    erc20(token).transfer(RECIPIENT, 500);
    start_cheat_caller_address(token, BURNER);
    let accounts = array![HOLDER, RECIPIENT].span();
    let values = array![100, 200].span();
    let mut spy = spy_events();
    burn(token).batch_burn(accounts, values);
    assert_eq!(erc20(token).balance_of(RECIPIENT), 300);
    assert_eq!(erc20(token).total_supply(), SUPPLY - 300);
    spy.assert_emitted_single(token, transfer_event(HOLDER, ZERO, 100));
    spy.assert_emitted_single(token, transfer_event(RECIPIENT, ZERO, 200));
    spy
        .assert_only_event(
            token,
            BurnComponent::Event::BatchBurn(
                BurnComponent::BatchBurn {
                    burner: BURNER, accounts, values, data: array![].span(),
                },
            ),
        );
}

#[test]
fn batch_burn_with_data_emits_data() {
    let token = setup();
    let accounts = array![HOLDER].span();
    let values = array![100].span();
    let data = array!['batch'].span();
    let mut spy = spy_events();
    IBurnBatchERC20Dispatcher { contract_address: token }
        .batch_burn_with_data(accounts, values, data);
    spy.assert_emitted_single(token, transfer_event(HOLDER, ZERO, 100));
    spy
        .assert_only_event(
            token,
            BurnComponent::Event::BatchBurn(
                BurnComponent::BatchBurn { burner: BURNER, accounts, values, data },
            ),
        );
}

#[test]
#[feature("safe_dispatcher")]
fn batch_burn_rejects_empty_accounts() {
    let token = setup();
    assert_reverted_with(
        safe_burn(token).batch_burn(array![].span(), array![].span()),
        array![errors::BURN_EMPTY_ACCOUNTS].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn batch_burn_rejects_length_mismatch() {
    let token = setup();
    assert_reverted_with(
        safe_burn(token).batch_burn(array![HOLDER].span(), array![1, 2].span()),
        array![errors::BURN_ACCOUNTS_VALUES_LEN_MISMATCH].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn batch_burn_is_atomic_on_frozen_account() {
    let token = setup();
    freeze(token, RECIPIENT);
    assert_reverted_with(
        safe_burn(token).batch_burn(array![HOLDER, RECIPIENT].span(), array![1, 0].span()),
        array![errors::ERC7943_CANNOT_SEND, RECIPIENT.into()].span(),
    );
    assert_eq!(erc20(token).balance_of(HOLDER), SUPPLY);
}

//
// burn_from / burn_self
//

#[test]
fn burn_from_spends_allowance_and_emits_burn_from() {
    let token = setup();
    grant(token, BURNER_FROM_ROLE, OTHER);
    start_cheat_caller_address(token, HOLDER);
    erc20(token).approve(OTHER, 150);
    start_cheat_caller_address(token, OTHER);
    let mut spy = spy_events();
    IBurnFromERC20Dispatcher { contract_address: token }.burn_from(HOLDER, 100);
    assert_eq!(erc20(token).allowance(HOLDER, OTHER), 50);
    assert_eq!(erc20(token).balance_of(HOLDER), SUPPLY - 100);
    spy
        .assert_emitted_single(
            token,
            ERC20BaseComponent::Event::Spend(
                ERC20BaseComponent::Spend { account: HOLDER, spender: OTHER, value: 100 },
            ),
        );
    spy.assert_emitted_single(token, transfer_event(HOLDER, ZERO, 100));
    spy.assert_only_event(token, burn_from_event(OTHER, HOLDER, 100));
}

#[test]
#[feature("safe_dispatcher")]
fn burn_from_requires_burner_from_role() {
    let token = setup();
    assert_reverted_with(
        IBurnFromERC20SafeDispatcher { contract_address: token }.burn_from(HOLDER, 1),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn burn_from_requires_allowance() {
    let token = setup();
    grant(token, BURNER_FROM_ROLE, OTHER);
    start_cheat_caller_address(token, OTHER);
    assert_reverted_with(
        IBurnFromERC20SafeDispatcher { contract_address: token }.burn_from(HOLDER, 1),
        array![ERC20Component::Errors::INSUFFICIENT_ALLOWANCE].span(),
    );
}

#[test]
fn burn_self_burns_caller_tokens() {
    let token = setup();
    grant(token, BURNER_SELF_ROLE, HOLDER);
    start_cheat_caller_address(token, HOLDER);
    let mut spy = spy_events();
    IBurnFromERC20Dispatcher { contract_address: token }.burn_self(100);
    assert_eq!(erc20(token).balance_of(HOLDER), SUPPLY - 100);
    spy.assert_emitted_single(token, transfer_event(HOLDER, ZERO, 100));
    spy.assert_only_event(token, burn_from_event(HOLDER, HOLDER, 100));
}

#[test]
#[feature("safe_dispatcher")]
fn burn_self_requires_burner_self_role() {
    let token = setup();
    start_cheat_caller_address(token, HOLDER);
    assert_reverted_with(
        IBurnFromERC20SafeDispatcher { contract_address: token }.burn_self(1),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn burn_self_reverts_when_frozen() {
    let token = setup();
    grant(token, BURNER_SELF_ROLE, HOLDER);
    freeze(token, HOLDER);
    start_cheat_caller_address(token, HOLDER);
    assert_reverted_with(
        IBurnFromERC20SafeDispatcher { contract_address: token }.burn_self(1),
        array![errors::ERC7943_CANNOT_SEND, HOLDER.into()].span(),
    );
}

//
// burn_and_mint: each leg under its own role
//

#[test]
fn burn_and_mint_with_both_roles() {
    let token = setup();
    grant(token, MINTER_ROLE, BURNER);
    start_cheat_caller_address(token, BURNER);
    let data = array!['swap'].span();
    let mut spy = spy_events();
    IBurnMintERC20Dispatcher { contract_address: token }
        .burn_and_mint(HOLDER, RECIPIENT, 100, 70, data);
    assert_eq!(erc20(token).balance_of(HOLDER), SUPPLY - 100);
    assert_eq!(erc20(token).balance_of(RECIPIENT), 70);
    spy.assert_emitted_single(token, transfer_event(HOLDER, ZERO, 100));
    spy.assert_emitted_single(token, burn_event(HOLDER, 100, data));
    spy.assert_emitted_single(token, transfer_event(ZERO, RECIPIENT, 70));
    spy
        .assert_only_event(
            token,
            MintComponent::Event::Mint(
                MintComponent::Mint { minter: BURNER, account: RECIPIENT, value: 70, data },
            ),
        );
}

#[test]
#[feature("safe_dispatcher")]
fn burn_and_mint_requires_minter_role_for_mint_leg() {
    let token = setup();
    assert_reverted_with(
        IBurnMintERC20SafeDispatcher { contract_address: token }
            .burn_and_mint(HOLDER, RECIPIENT, 100, 70, array![].span()),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
    assert_eq!(erc20(token).balance_of(HOLDER), SUPPLY);
}

#[test]
#[feature("safe_dispatcher")]
fn burn_and_mint_requires_burner_role_for_burn_leg() {
    let token = setup();
    grant(token, MINTER_ROLE, OTHER);
    start_cheat_caller_address(token, OTHER);
    assert_reverted_with(
        IBurnMintERC20SafeDispatcher { contract_address: token }
            .burn_and_mint(HOLDER, RECIPIENT, 100, 70, array![].span()),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

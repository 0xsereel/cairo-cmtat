// SPDX-License-Identifier: MPL-2.0
// MintComponent with the CMTATBaseCommon check chain.

use cairo_cmtat::components::mint::MintComponent;
use cairo_cmtat::errors;
use cairo_cmtat::interfaces::enforcement::{
    IERC3643EnforcementDispatcher, IERC3643EnforcementDispatcherTrait,
};
use cairo_cmtat::interfaces::erc20_enforcement::{
    IERC3643ERC20EnforcementDispatcher, IERC3643ERC20EnforcementDispatcherTrait,
};
use cairo_cmtat::interfaces::mint::{
    IERC3643BatchTransferDispatcher, IERC3643BatchTransferDispatcherTrait,
    IERC3643BatchTransferSafeDispatcher, IERC3643BatchTransferSafeDispatcherTrait,
    IERC3643MintDispatcher, IERC3643MintDispatcherTrait, IERC3643MintSafeDispatcher,
    IERC3643MintSafeDispatcherTrait, IERC5679MintDispatcher, IERC5679MintDispatcherTrait,
};
use cairo_cmtat::interfaces::pause::{
    IERC3643PauseDispatcher, IERC3643PauseDispatcherTrait, IERC8343Dispatcher,
    IERC8343DispatcherTrait,
};
use cairo_cmtat::roles::{ENFORCER_ROLE, ERC20ENFORCER_ROLE, MINTER_ROLE, PAUSER_ROLE};
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
    ADMIN, ENFORCER, ERC20ENFORCER, HOLDER, MINTER, OTHER, PAUSER, RECIPIENT, SUPPLY, ZERO,
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
    access.grant_role(MINTER_ROLE, MINTER);
    start_cheat_caller_address(token, MINTER);
    token
}

fn mint(token: ContractAddress) -> IERC3643MintDispatcher {
    IERC3643MintDispatcher { contract_address: token }
}

fn safe_mint(token: ContractAddress) -> IERC3643MintSafeDispatcher {
    IERC3643MintSafeDispatcher { contract_address: token }
}

fn batch_transfer(token: ContractAddress) -> IERC3643BatchTransferDispatcher {
    IERC3643BatchTransferDispatcher { contract_address: token }
}

fn safe_batch_transfer(token: ContractAddress) -> IERC3643BatchTransferSafeDispatcher {
    IERC3643BatchTransferSafeDispatcher { contract_address: token }
}

fn erc20(token: ContractAddress) -> IERC20Dispatcher {
    IERC20Dispatcher { contract_address: token }
}

fn pause(token: ContractAddress) {
    start_cheat_caller_address(token, PAUSER);
    IERC3643PauseDispatcher { contract_address: token }.pause();
    start_cheat_caller_address(token, MINTER);
}

fn deactivate(token: ContractAddress) {
    pause(token);
    start_cheat_caller_address(token, ADMIN);
    IERC8343Dispatcher { contract_address: token }.deactivate_contract();
    start_cheat_caller_address(token, MINTER);
}

fn freeze(token: ContractAddress, account: ContractAddress) {
    start_cheat_caller_address(token, ENFORCER);
    IERC3643EnforcementDispatcher { contract_address: token }.set_address_frozen(account, true);
    start_cheat_caller_address(token, MINTER);
}

fn transfer_event(
    from: ContractAddress, to: ContractAddress, value: u256,
) -> ERC20Component::Event {
    ERC20Component::Event::Transfer(ERC20Component::Transfer { from, to, value })
}

fn mint_event(account: ContractAddress, value: u256, data: Span<felt252>) -> MintComponent::Event {
    MintComponent::Event::Mint(MintComponent::Mint { minter: MINTER, account, value, data })
}

//
// mint
//

#[test]
fn mint_increases_balance_and_supply() {
    let token = setup();
    let mut spy = spy_events();
    mint(token).mint(RECIPIENT, 100);
    assert_eq!(erc20(token).balance_of(RECIPIENT), 100);
    assert_eq!(erc20(token).total_supply(), SUPPLY + 100);
    spy.assert_emitted_single(token, transfer_event(ZERO, RECIPIENT, 100));
    spy.assert_only_event(token, mint_event(RECIPIENT, 100, array![].span()));
}

#[test]
fn mint_with_data_emits_data() {
    let token = setup();
    let data = array!['issuance', 1].span();
    let mut spy = spy_events();
    IERC5679MintDispatcher { contract_address: token }.mint_with_data(RECIPIENT, 100, data);
    spy.assert_emitted_single(token, transfer_event(ZERO, RECIPIENT, 100));
    spy.assert_only_event(token, mint_event(RECIPIENT, 100, data));
}

#[test]
#[feature("safe_dispatcher")]
fn mint_requires_minter_role() {
    let token = setup();
    start_cheat_caller_address(token, OTHER);
    assert_reverted_with(
        safe_mint(token).mint(RECIPIENT, 1),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

/// Pause does not block minting.
#[test]
fn mint_succeeds_while_paused() {
    let token = setup();
    pause(token);
    mint(token).mint(RECIPIENT, 100);
    assert_eq!(erc20(token).balance_of(RECIPIENT), 100);
}

#[test]
#[feature("safe_dispatcher")]
fn mint_reverts_when_deactivated() {
    let token = setup();
    deactivate(token);
    assert_reverted_with(
        safe_mint(token).mint(RECIPIENT, 1), array![errors::ENFORCED_DEACTIVATION].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn mint_reverts_when_recipient_frozen() {
    let token = setup();
    freeze(token, RECIPIENT);
    assert_reverted_with(
        safe_mint(token).mint(RECIPIENT, 1),
        array![errors::ERC7943_CANNOT_RECEIVE, RECIPIENT.into()].span(),
    );
}

/// A frozen minter can still mint: only the recipient is checked.
#[test]
fn mint_by_frozen_minter_succeeds() {
    let token = setup();
    freeze(token, MINTER);
    mint(token).mint(RECIPIENT, 100);
    assert_eq!(erc20(token).balance_of(RECIPIENT), 100);
}

#[test]
fn batch_mint_by_frozen_minter_succeeds() {
    let token = setup();
    freeze(token, MINTER);
    mint(token).batch_mint(array![RECIPIENT, OTHER].span(), array![100, 200].span());
    assert_eq!(erc20(token).balance_of(RECIPIENT), 100);
    assert_eq!(erc20(token).balance_of(OTHER), 200);
}

#[test]
#[feature("safe_dispatcher")]
fn mint_to_zero_reverts() {
    let token = setup();
    assert_reverted_with(
        safe_mint(token).mint(ZERO, 1), array![ERC20Component::Errors::MINT_TO_ZERO].span(),
    );
}

//
// batch_mint
//

#[test]
fn batch_mint_emits_batch_event_not_per_account_mint() {
    let token = setup();
    let accounts = array![RECIPIENT, OTHER].span();
    let values = array![100, 200].span();
    let mut spy = spy_events();
    mint(token).batch_mint(accounts, values);
    assert_eq!(erc20(token).balance_of(RECIPIENT), 100);
    assert_eq!(erc20(token).balance_of(OTHER), 200);
    spy.assert_emitted_single(token, transfer_event(ZERO, RECIPIENT, 100));
    spy.assert_emitted_single(token, transfer_event(ZERO, OTHER, 200));
    spy
        .assert_only_event(
            token,
            MintComponent::Event::BatchMint(
                MintComponent::BatchMint { minter: MINTER, accounts, values },
            ),
        );
}

#[test]
#[feature("safe_dispatcher")]
fn batch_mint_requires_minter_role() {
    let token = setup();
    start_cheat_caller_address(token, OTHER);
    assert_reverted_with(
        safe_mint(token).batch_mint(array![RECIPIENT].span(), array![1].span()),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn batch_mint_rejects_empty_accounts() {
    let token = setup();
    assert_reverted_with(
        safe_mint(token).batch_mint(array![].span(), array![].span()),
        array![errors::MINT_EMPTY_ACCOUNTS].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn batch_mint_rejects_length_mismatch() {
    let token = setup();
    assert_reverted_with(
        safe_mint(token).batch_mint(array![RECIPIENT, OTHER].span(), array![1].span()),
        array![errors::MINT_ACCOUNTS_VALUES_LEN_MISMATCH].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn batch_mint_is_atomic_on_frozen_recipient() {
    let token = setup();
    freeze(token, OTHER);
    assert_reverted_with(
        safe_mint(token).batch_mint(array![RECIPIENT, OTHER].span(), array![1, 1].span()),
        array![errors::ERC7943_CANNOT_RECEIVE, OTHER.into()].span(),
    );
    assert_eq!(erc20(token).balance_of(RECIPIENT), 0);
}

//
// batch_transfer: standard transfers from the minter
//

fn setup_funded_minter() -> ContractAddress {
    let token = setup();
    mint(token).mint(MINTER, 1000);
    token
}

#[test]
fn batch_transfer_moves_minter_tokens() {
    let token = setup_funded_minter();
    let mut spy = spy_events();
    assert!(
        batch_transfer(token)
            .batch_transfer(array![RECIPIENT, OTHER].span(), array![100, 200].span()),
    );
    assert_eq!(erc20(token).balance_of(MINTER), 700);
    assert_eq!(erc20(token).balance_of(RECIPIENT), 100);
    assert_eq!(erc20(token).balance_of(OTHER), 200);
    spy.assert_emitted_single(token, transfer_event(MINTER, RECIPIENT, 100));
    spy.assert_only_event(token, transfer_event(MINTER, OTHER, 200));
}

/// The second transfer exceeds what the first left; nothing moves.
#[test]
#[feature("safe_dispatcher")]
fn batch_transfer_is_atomic_on_insufficient_balance() {
    let token = setup_funded_minter();
    assert_reverted_with(
        safe_batch_transfer(token)
            .batch_transfer(array![RECIPIENT, OTHER].span(), array![600, 500].span()),
        array![ERC20Component::Errors::INSUFFICIENT_BALANCE].span(),
    );
    assert_eq!(erc20(token).balance_of(MINTER), 1000);
    assert_eq!(erc20(token).balance_of(RECIPIENT), 0);
}

#[test]
#[feature("safe_dispatcher")]
fn batch_transfer_requires_minter_role() {
    let token = setup_funded_minter();
    start_cheat_caller_address(token, HOLDER);
    assert_reverted_with(
        safe_batch_transfer(token).batch_transfer(array![RECIPIENT].span(), array![1].span()),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn batch_transfer_reverts_when_paused() {
    let token = setup_funded_minter();
    pause(token);
    assert_reverted_with(
        safe_batch_transfer(token).batch_transfer(array![RECIPIENT].span(), array![1].span()),
        array![errors::ENFORCED_PAUSE].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn batch_transfer_reverts_when_minter_frozen() {
    let token = setup_funded_minter();
    freeze(token, MINTER);
    assert_reverted_with(
        safe_batch_transfer(token).batch_transfer(array![RECIPIENT].span(), array![1].span()),
        array![errors::ERC7943_CANNOT_SEND, MINTER.into()].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn batch_transfer_reverts_when_recipient_frozen() {
    let token = setup_funded_minter();
    freeze(token, OTHER);
    assert_reverted_with(
        safe_batch_transfer(token)
            .batch_transfer(array![RECIPIENT, OTHER].span(), array![1, 1].span()),
        array![errors::ERC7943_CANNOT_RECEIVE, OTHER.into()].span(),
    );
    assert_eq!(erc20(token).balance_of(RECIPIENT), 0);
}

#[test]
#[feature("safe_dispatcher")]
fn batch_transfer_respects_active_balance() {
    let token = setup_funded_minter();
    start_cheat_caller_address(token, ERC20ENFORCER);
    IERC3643ERC20EnforcementDispatcher { contract_address: token }
        .freeze_partial_tokens(MINTER, 900);
    start_cheat_caller_address(token, MINTER);
    let mut expected = array![errors::ERC7943_INSUFFICIENT_UNFROZEN_BAL];
    expected.append_serde(MINTER);
    expected.append_serde(101_u256);
    expected.append_serde(100_u256);
    assert_reverted_with(
        safe_batch_transfer(token).batch_transfer(array![RECIPIENT].span(), array![101].span()),
        expected.span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn batch_transfer_rejects_empty_tos() {
    let token = setup_funded_minter();
    assert_reverted_with(
        safe_batch_transfer(token).batch_transfer(array![].span(), array![].span()),
        array![errors::MINT_EMPTY_TOS].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn batch_transfer_rejects_length_mismatch() {
    let token = setup_funded_minter();
    assert_reverted_with(
        safe_batch_transfer(token).batch_transfer(array![RECIPIENT].span(), array![1, 2].span()),
        array![errors::MINT_TOS_VALUES_LEN_MISMATCH].span(),
    );
}

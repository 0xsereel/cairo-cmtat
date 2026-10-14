// SPDX-License-Identifier: MPL-2.0
// SnapshotComponent: engine management and one `operate_on_transfer` per balance
// change, carrying pre-update balances and total supply.

use cairo_cmtat::components::snapshot::SnapshotComponent;
use cairo_cmtat::errors;
use cairo_cmtat::interfaces::burn::{IERC3643BurnDispatcher, IERC3643BurnDispatcherTrait};
use cairo_cmtat::interfaces::erc20_enforcement::{
    IERC7943FungibleEnforcementDispatcher, IERC7943FungibleEnforcementDispatcherTrait,
};
use cairo_cmtat::interfaces::mint::{IERC3643MintDispatcher, IERC3643MintDispatcherTrait};
use cairo_cmtat::interfaces::snapshot::{
    ISnapshotEngineModuleDispatcher, ISnapshotEngineModuleDispatcherTrait,
    ISnapshotEngineModuleSafeDispatcher, ISnapshotEngineModuleSafeDispatcherTrait,
};
use cairo_cmtat::mocks::snapshot_engine_recorder::{
    ISnapshotEngineRecorderDispatcher, ISnapshotEngineRecorderDispatcherTrait, SnapshotCall,
};
use cairo_cmtat::roles::{BURNER_ROLE, MINTER_ROLE, SNAPSHOOTER_ROLE};
use openzeppelin::access::accesscontrol::AccessControlComponent;
use openzeppelin::interfaces::accesscontrol::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::interfaces::erc20::{
    IERC20Dispatcher, IERC20DispatcherTrait, IERC20SafeDispatcher, IERC20SafeDispatcherTrait,
};
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin_testing::{EventSpyExt, spy_events};
use snforge_std::start_cheat_caller_address;
use starknet::ContractAddress;
use crate::utils::{
    ADMIN, BURNER, HOLDER, MINTER, OTHER, RECIPIENT, SPENDER, SUPPLY, ZERO, assert_reverted_with,
};

/// Snapshot engine manager.
const SNAPSHOOTER: ContractAddress = OTHER;

#[derive(Copy, Drop)]
struct Setup {
    token: ContractAddress,
    engine: ContractAddress,
}

fn deploy_token() -> ContractAddress {
    let mut calldata = array![];
    calldata.append_serde(18_u8);
    calldata.append_serde(SUPPLY);
    calldata.append_serde(HOLDER);
    calldata.append_serde(ADMIN);
    let token = openzeppelin_testing::declare_and_deploy("CommonMock", calldata);
    start_cheat_caller_address(token, ADMIN);
    let access = IAccessControlDispatcher { contract_address: token };
    access.grant_role(MINTER_ROLE, MINTER);
    access.grant_role(BURNER_ROLE, BURNER);
    access.grant_role(SNAPSHOOTER_ROLE, SNAPSHOOTER);
    token
}

fn setup() -> Setup {
    let token = deploy_token();
    let engine = openzeppelin_testing::declare_and_deploy("SnapshotEngineRecorder", array![]);
    start_cheat_caller_address(token, SNAPSHOOTER);
    ISnapshotEngineModuleDispatcher { contract_address: token }.set_snapshot_engine(engine);
    Setup { token, engine }
}

fn recorder(s: Setup) -> ISnapshotEngineRecorderDispatcher {
    ISnapshotEngineRecorderDispatcher { contract_address: s.engine }
}

fn erc20(token: ContractAddress) -> IERC20Dispatcher {
    IERC20Dispatcher { contract_address: token }
}

fn call(
    from: ContractAddress,
    to: ContractAddress,
    balance_from: u256,
    balance_to: u256,
    total_supply: u256,
) -> SnapshotCall {
    SnapshotCall { from, to, balance_from, balance_to, total_supply }
}

fn assert_single_call(s: Setup, expected: SnapshotCall) {
    assert_eq!(recorder(s).call_count(), 1);
    assert_eq!(recorder(s).call_at(0), expected);
}

//
// Engine management
//

#[test]
fn set_snapshot_engine_stores_and_emits() {
    let token = deploy_token();
    let engine = openzeppelin_testing::declare_and_deploy("SnapshotEngineRecorder", array![]);
    start_cheat_caller_address(token, SNAPSHOOTER);
    let mut spy = spy_events();
    let module = ISnapshotEngineModuleDispatcher { contract_address: token };
    module.set_snapshot_engine(engine);
    assert_eq!(module.snapshot_engine(), engine);
    spy
        .assert_only_event(
            token,
            SnapshotComponent::Event::SnapshotEngine(
                SnapshotComponent::SnapshotEngineSet { new_snapshot_engine: engine },
            ),
        );
}

#[test]
#[feature("safe_dispatcher")]
fn set_snapshot_engine_rejects_same_value() {
    let s = setup();
    assert_reverted_with(
        ISnapshotEngineModuleSafeDispatcher { contract_address: s.token }
            .set_snapshot_engine(s.engine),
        array![errors::SNAPSHOT_SAME_VALUE].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn set_snapshot_engine_requires_snapshooter_role() {
    let s = setup();
    start_cheat_caller_address(s.token, MINTER);
    assert_reverted_with(
        ISnapshotEngineModuleSafeDispatcher { contract_address: s.token }.set_snapshot_engine(ZERO),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

#[test]
fn removing_engine_stops_notifications() {
    let s = setup();
    ISnapshotEngineModuleDispatcher { contract_address: s.token }.set_snapshot_engine(ZERO);
    start_cheat_caller_address(s.token, HOLDER);
    erc20(s.token).transfer(RECIPIENT, 1);
    assert_eq!(recorder(s).call_count(), 0);
}

//
// One notification per balance change, with pre-update values
//

#[test]
fn transfer_notifies_with_pre_transfer_balances() {
    let s = setup();
    start_cheat_caller_address(s.token, HOLDER);
    erc20(s.token).transfer(RECIPIENT, 100);
    assert_single_call(s, call(HOLDER, RECIPIENT, SUPPLY, 0, SUPPLY));
}

#[test]
fn consecutive_transfers_report_updated_balances() {
    let s = setup();
    start_cheat_caller_address(s.token, HOLDER);
    erc20(s.token).transfer(RECIPIENT, 100);
    erc20(s.token).transfer(RECIPIENT, 50);
    assert_eq!(recorder(s).call_count(), 2);
    assert_eq!(recorder(s).call_at(1), call(HOLDER, RECIPIENT, SUPPLY - 100, 100, SUPPLY));
}

#[test]
fn mint_notifies_with_pre_mint_supply() {
    let s = setup();
    start_cheat_caller_address(s.token, MINTER);
    IERC3643MintDispatcher { contract_address: s.token }.mint(RECIPIENT, 50);
    assert_single_call(s, call(ZERO, RECIPIENT, 0, 0, SUPPLY));
}

#[test]
fn burn_notifies_with_pre_burn_supply() {
    let s = setup();
    start_cheat_caller_address(s.token, BURNER);
    IERC3643BurnDispatcher { contract_address: s.token }.burn(HOLDER, 30);
    assert_single_call(s, call(HOLDER, ZERO, SUPPLY, 0, SUPPLY));
}

#[test]
fn self_transfer_reports_unchanged_balance() {
    let s = setup();
    start_cheat_caller_address(s.token, HOLDER);
    erc20(s.token).transfer(HOLDER, 100);
    assert_single_call(s, call(HOLDER, HOLDER, SUPPLY, SUPPLY, SUPPLY));
}

#[test]
fn transfer_from_notifies_once() {
    let s = setup();
    start_cheat_caller_address(s.token, HOLDER);
    erc20(s.token).approve(SPENDER, 10);
    start_cheat_caller_address(s.token, SPENDER);
    erc20(s.token).transfer_from(HOLDER, RECIPIENT, 10);
    assert_single_call(s, call(HOLDER, RECIPIENT, SUPPLY, 0, SUPPLY));
}

#[test]
fn batch_mint_notifies_per_account() {
    let s = setup();
    start_cheat_caller_address(s.token, MINTER);
    IERC3643MintDispatcher { contract_address: s.token }
        .batch_mint(array![RECIPIENT, OTHER].span(), array![10, 20].span());
    assert_eq!(recorder(s).call_count(), 2);
    assert_eq!(recorder(s).call_at(0), call(ZERO, RECIPIENT, 0, 0, SUPPLY));
    assert_eq!(recorder(s).call_at(1), call(ZERO, OTHER, 0, 0, SUPPLY + 10));
}

#[test]
fn forced_transfers_notify() {
    let s = setup();
    start_cheat_caller_address(s.token, ADMIN);
    let enforcement = IERC7943FungibleEnforcementDispatcher { contract_address: s.token };
    enforcement.forced_transfer(HOLDER, RECIPIENT, 10);
    enforcement.forced_transfer(HOLDER, ZERO, 5);
    assert_eq!(recorder(s).call_count(), 2);
    assert_eq!(recorder(s).call_at(0), call(HOLDER, RECIPIENT, SUPPLY, 0, SUPPLY));
    assert_eq!(recorder(s).call_at(1), call(HOLDER, ZERO, SUPPLY - 10, 0, SUPPLY));
}

#[test]
#[feature("safe_dispatcher")]
fn reverted_transfer_does_not_notify() {
    let s = setup();
    start_cheat_caller_address(s.token, RECIPIENT);
    let result = IERC20SafeDispatcher { contract_address: s.token }.transfer(HOLDER, 1);
    assert!(result.is_err());
    assert_eq!(recorder(s).call_count(), 0);
}

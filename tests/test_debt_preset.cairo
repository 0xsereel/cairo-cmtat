// SPDX-License-Identifier: MPL-2.0
// CMTATDebt preset: constructor, engines and debt. The ABI surface, roles and
// upgrades are covered for every preset by test_presets; validation by
// test_validation_matrix.

use cairo_cmtat::interfaces::debt::{
    CreditEvents, IDebtModuleDispatcher, IDebtModuleDispatcherTrait,
};
use cairo_cmtat::interfaces::extra_information::{ICMTATBaseDispatcher, ICMTATBaseDispatcherTrait};
use cairo_cmtat::interfaces::mint::{IERC3643MintDispatcher, IERC3643MintDispatcherTrait};
use cairo_cmtat::interfaces::rule_engine::{
    IValidationRuleEngineDispatcher, IValidationRuleEngineDispatcherTrait,
};
use cairo_cmtat::interfaces::snapshot::{
    ISnapshotEngineModuleDispatcher, ISnapshotEngineModuleDispatcherTrait,
};
use cairo_cmtat::mocks::rule_engine_recorder::{
    IRuleEngineRecorderDispatcher, IRuleEngineRecorderDispatcherTrait,
};
use cairo_cmtat::mocks::snapshot_engine_recorder::{
    ISnapshotEngineRecorderDispatcher, ISnapshotEngineRecorderDispatcherTrait, SnapshotCall,
};
use cairo_cmtat::roles::{DEBT_ROLE, SNAPSHOOTER_ROLE};
use openzeppelin::interfaces::accesscontrol::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::interfaces::erc20::{IERC20MetadataDispatcher, IERC20MetadataDispatcherTrait};
use snforge_std::start_cheat_caller_address;
use crate::utils::{ADMIN, HOLDER, OTHER, ZERO, deploy_debt_preset};

//
// Deployment and engines
//

#[test]
fn constructor_sets_attributes_and_rule_engine() {
    let engine = openzeppelin_testing::declare_and_deploy("RuleEngineRecorder", array![]);
    let token = deploy_debt_preset(engine);
    assert_eq!(IERC20MetadataDispatcher { contract_address: token }.symbol(), "STD");
    assert_eq!(ICMTATBaseDispatcher { contract_address: token }.token_id(), "CH0000000000");
    assert_eq!(IValidationRuleEngineDispatcher { contract_address: token }.rule_engine(), engine);
    assert_eq!(ISnapshotEngineModuleDispatcher { contract_address: token }.snapshot_engine(), ZERO);
    start_cheat_caller_address(token, ADMIN);
    IERC3643MintDispatcher { contract_address: token }.mint(HOLDER, 10);
    assert_eq!(IRuleEngineRecorderDispatcher { contract_address: engine }.call_count(), 1);
}

#[test]
fn snapshot_engine_is_notified() {
    let token = deploy_debt_preset(ZERO);
    let engine = openzeppelin_testing::declare_and_deploy("SnapshotEngineRecorder", array![]);
    start_cheat_caller_address(token, ADMIN);
    IAccessControlDispatcher { contract_address: token }.grant_role(SNAPSHOOTER_ROLE, OTHER);
    start_cheat_caller_address(token, OTHER);
    ISnapshotEngineModuleDispatcher { contract_address: token }.set_snapshot_engine(engine);
    start_cheat_caller_address(token, ADMIN);
    IERC3643MintDispatcher { contract_address: token }.mint(HOLDER, 10);
    let recorder = ISnapshotEngineRecorderDispatcher { contract_address: engine };
    assert_eq!(recorder.call_count(), 1);
    assert_eq!(
        recorder.call_at(0),
        SnapshotCall { from: ZERO, to: HOLDER, balance_from: 0, balance_to: 0, total_supply: 0 },
    );
}

#[test]
fn debt_is_managed_under_debt_role() {
    let token = deploy_debt_preset(ZERO);
    start_cheat_caller_address(token, ADMIN);
    IAccessControlDispatcher { contract_address: token }.grant_role(DEBT_ROLE, OTHER);
    start_cheat_caller_address(token, OTHER);
    let events = CreditEvents { flag_default: false, flag_redeemed: true, rating: "AA" };
    IDebtModuleDispatcher { contract_address: token }.set_credit_events(events.clone());
    assert_eq!(IDebtModuleDispatcher { contract_address: token }.credit_events(), events);
}


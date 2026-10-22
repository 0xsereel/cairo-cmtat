// SPDX-License-Identifier: MPL-2.0
// CMTATSnapshot preset: constructor and the SnapshotEngine callback. The ABI
// surface, roles and upgrades are covered for every preset by test_presets;
// validation by test_validation_matrix.

use cairo_cmtat::interfaces::burn::{IBurnFromERC20Dispatcher, IBurnFromERC20DispatcherTrait};
use cairo_cmtat::interfaces::mint::{IERC3643MintDispatcher, IERC3643MintDispatcherTrait};
use cairo_cmtat::interfaces::rule_engine::{
    IValidationRuleEngineDispatcher, IValidationRuleEngineDispatcherTrait,
};
use cairo_cmtat::interfaces::snapshot::{
    ISnapshotEngineModuleDispatcher, ISnapshotEngineModuleDispatcherTrait,
};
use cairo_cmtat::mocks::snapshot_engine_recorder::{
    ISnapshotEngineRecorderDispatcher, ISnapshotEngineRecorderDispatcherTrait, SnapshotCall,
};
use cairo_cmtat::roles::{BURNER_FROM_ROLE, SNAPSHOOTER_ROLE};
use openzeppelin::interfaces::accesscontrol::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::start_cheat_caller_address;
use crate::utils::{ADMIN, HOLDER, OTHER, RECIPIENT, SPENDER, ZERO, deploy_snapshot_preset};

#[test]
fn constructor_sets_rule_engine_and_no_snapshot_engine() {
    let engine = openzeppelin_testing::declare_and_deploy("RuleEngineRecorder", array![]);
    let token = deploy_snapshot_preset(engine);
    assert_eq!(IValidationRuleEngineDispatcher { contract_address: token }.rule_engine(), engine);
    assert_eq!(ISnapshotEngineModuleDispatcher { contract_address: token }.snapshot_engine(), ZERO);
}

/// Every balance change reaches the SnapshotEngine, including burn-from.
#[test]
fn snapshot_engine_sees_transfers_and_burns() {
    let token = deploy_snapshot_preset(ZERO);
    let engine = openzeppelin_testing::declare_and_deploy("SnapshotEngineRecorder", array![]);
    start_cheat_caller_address(token, ADMIN);
    let access = IAccessControlDispatcher { contract_address: token };
    access.grant_role(SNAPSHOOTER_ROLE, OTHER);
    access.grant_role(BURNER_FROM_ROLE, SPENDER);
    IERC3643MintDispatcher { contract_address: token }.mint(HOLDER, 100);
    start_cheat_caller_address(token, OTHER);
    ISnapshotEngineModuleDispatcher { contract_address: token }.set_snapshot_engine(engine);

    start_cheat_caller_address(token, HOLDER);
    let erc20 = IERC20Dispatcher { contract_address: token };
    erc20.transfer(RECIPIENT, 40);
    erc20.approve(SPENDER, 10);
    start_cheat_caller_address(token, SPENDER);
    IBurnFromERC20Dispatcher { contract_address: token }.burn_from(HOLDER, 10);

    let recorder = ISnapshotEngineRecorderDispatcher { contract_address: engine };
    assert_eq!(recorder.call_count(), 2);
    assert_eq!(
        recorder.call_at(0),
        SnapshotCall {
            from: HOLDER, to: RECIPIENT, balance_from: 100, balance_to: 0, total_supply: 100,
        },
    );
    assert_eq!(
        recorder.call_at(1),
        SnapshotCall { from: HOLDER, to: ZERO, balance_from: 60, balance_to: 0, total_supply: 100 },
    );
}


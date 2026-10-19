// SPDX-License-Identifier: MPL-2.0
// CMTATSnapshot preset: deployment, engines, introspection, upgrades and ABI
// surface. The validation behaviour is covered by test_validation_matrix.

use cairo_cmtat::interfaces::allowlist::{
    IAllowlistModuleSafeDispatcher, IAllowlistModuleSafeDispatcherTrait,
};
use cairo_cmtat::interfaces::burn::{
    IBurnFromERC20Dispatcher, IBurnFromERC20DispatcherTrait, IForcedBurnERC20SafeDispatcher,
    IForcedBurnERC20SafeDispatcherTrait,
};
use cairo_cmtat::interfaces::debt::{IDebtModuleSafeDispatcher, IDebtModuleSafeDispatcherTrait};
use cairo_cmtat::interfaces::erc1404::{IERC1404Dispatcher, IERC1404DispatcherTrait, TRANSFER_OK};
use cairo_cmtat::interfaces::erc20_enforcement::{
    IERC7551ERC20EnforcementSafeDispatcher, IERC7551ERC20EnforcementSafeDispatcherTrait,
};
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
use openzeppelin::access::accesscontrol::AccessControlComponent;
use openzeppelin::interfaces::accesscontrol::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::interfaces::upgrades::{
    IUpgradeableDispatcher, IUpgradeableDispatcherTrait, IUpgradeableSafeDispatcher,
    IUpgradeableSafeDispatcherTrait,
};
use snforge_std::{DeclareResultTrait, declare, get_class_hash, start_cheat_caller_address};
use crate::utils::{
    ADMIN, HOLDER, OTHER, RECIPIENT, SPENDER, ZERO, assert_reverted_with, deploy_snapshot_preset,
};

fn entrypoint_not_found() -> Array<felt252> {
    array!['ENTRYPOINT_NOT_FOUND', 'ENTRYPOINT_FAILED']
}

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

#[test]
fn has_erc1404() {
    let token = deploy_snapshot_preset(ZERO);
    assert_eq!(
        IERC1404Dispatcher { contract_address: token }
            .detect_transfer_restriction(HOLDER, RECIPIENT, 0),
        TRANSFER_OK,
    );
}

#[test]
#[feature("safe_dispatcher")]
fn upgrade_requires_default_admin() {
    let token = deploy_snapshot_preset(ZERO);
    let new_class = *declare("ERC20Mock").unwrap().contract_class().class_hash;
    start_cheat_caller_address(token, OTHER);
    assert_reverted_with(
        IUpgradeableSafeDispatcher { contract_address: token }.upgrade(new_class),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
    start_cheat_caller_address(token, ADMIN);
    IUpgradeableDispatcher { contract_address: token }.upgrade(new_class);
    assert_eq!(get_class_hash(token), new_class);
}

#[test]
#[feature("safe_dispatcher")]
fn has_no_erc7551_debt_allowlist_or_forced_burn() {
    let token = deploy_snapshot_preset(ZERO);
    start_cheat_caller_address(token, ADMIN);
    assert_eq!(
        IERC7551ERC20EnforcementSafeDispatcher { contract_address: token }
            .get_active_balance_of(HOLDER)
            .unwrap_err(),
        entrypoint_not_found(),
    );
    assert_eq!(
        IDebtModuleSafeDispatcher { contract_address: token }.credit_events().unwrap_err(),
        entrypoint_not_found(),
    );
    assert_eq!(
        IAllowlistModuleSafeDispatcher { contract_address: token }
            .is_allowlist_enabled()
            .unwrap_err(),
        entrypoint_not_found(),
    );
    assert_eq!(
        IForcedBurnERC20SafeDispatcher { contract_address: token }
            .forced_burn(HOLDER, 1, array![].span())
            .unwrap_err(),
        entrypoint_not_found(),
    );
}

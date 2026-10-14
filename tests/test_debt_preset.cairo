// SPDX-License-Identifier: MPL-2.0
// CMTATDebt preset: deployment, engines, debt, introspection, upgrades and ABI
// surface. The validation behaviour is covered by test_validation_matrix.

use cairo_cmtat::interfaces::allowlist::{
    IAllowlistModuleSafeDispatcher, IAllowlistModuleSafeDispatcherTrait,
};
use cairo_cmtat::interfaces::burn::{
    IBurnFromERC20SafeDispatcher, IBurnFromERC20SafeDispatcherTrait, IForcedBurnERC20SafeDispatcher,
    IForcedBurnERC20SafeDispatcherTrait,
};
use cairo_cmtat::interfaces::debt::{
    CreditEvents, IDebtModuleDispatcher, IDebtModuleDispatcherTrait,
};
use cairo_cmtat::interfaces::erc1404::{IERC1404SafeDispatcher, IERC1404SafeDispatcherTrait};
use cairo_cmtat::interfaces::erc20_enforcement::{
    IERC7551ERC20EnforcementSafeDispatcher, IERC7551ERC20EnforcementSafeDispatcherTrait,
};
use cairo_cmtat::interfaces::extra_information::{ICMTATBaseDispatcher, ICMTATBaseDispatcherTrait};
use cairo_cmtat::interfaces::mint::{IERC3643MintDispatcher, IERC3643MintDispatcherTrait};
use cairo_cmtat::interfaces::pause::IERC8343_ID;
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
use openzeppelin::access::accesscontrol::AccessControlComponent;
use openzeppelin::interfaces::accesscontrol::{
    IACCESSCONTROL_ID, IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::interfaces::erc20::{IERC20MetadataDispatcher, IERC20MetadataDispatcherTrait};
use openzeppelin::interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait, ISRC5_ID};
use openzeppelin::interfaces::upgrades::{
    IUpgradeableDispatcher, IUpgradeableDispatcherTrait, IUpgradeableSafeDispatcher,
    IUpgradeableSafeDispatcherTrait,
};
use snforge_std::{DeclareResultTrait, declare, get_class_hash, start_cheat_caller_address};
use crate::utils::{ADMIN, HOLDER, OTHER, RECIPIENT, ZERO, assert_reverted_with, deploy_debt_preset};

fn entrypoint_not_found() -> Array<felt252> {
    array!['ENTRYPOINT_NOT_FOUND', 'ENTRYPOINT_FAILED']
}

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

#[test]
fn registers_interfaces() {
    let src5 = ISRC5Dispatcher { contract_address: deploy_debt_preset(ZERO) };
    assert!(src5.supports_interface(ISRC5_ID));
    assert!(src5.supports_interface(IACCESSCONTROL_ID));
    assert!(src5.supports_interface(IERC8343_ID));
}

#[test]
#[feature("safe_dispatcher")]
fn upgrade_requires_default_admin() {
    let token = deploy_debt_preset(ZERO);
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

//
// Debt omits ERC-1404, burn-from, ERC-7551 overloads, allowlist and forced burn
//

#[test]
#[feature("safe_dispatcher")]
fn has_no_erc1404_burn_from_erc7551_allowlist_or_forced_burn() {
    let token = deploy_debt_preset(ZERO);
    start_cheat_caller_address(token, ADMIN);
    assert_eq!(
        IERC1404SafeDispatcher { contract_address: token }
            .detect_transfer_restriction(HOLDER, RECIPIENT, 1)
            .unwrap_err(),
        entrypoint_not_found(),
    );
    assert_eq!(
        IBurnFromERC20SafeDispatcher { contract_address: token }.burn_from(HOLDER, 1).unwrap_err(),
        entrypoint_not_found(),
    );
    assert_eq!(
        IERC7551ERC20EnforcementSafeDispatcher { contract_address: token }
            .get_active_balance_of(HOLDER)
            .unwrap_err(),
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

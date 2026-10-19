// SPDX-License-Identifier: MPL-2.0
// Upgrades and the migration pattern: every preset starts at storage version 1;
// upgrading Standard to a V2 class and running its `migrate` keeps every
// module's storage, and `migrate` runs once, for the admin only.

use cairo_cmtat::components::upgrade::UpgradeComponent;
use cairo_cmtat::errors::INVALID_INITIALIZATION;
use cairo_cmtat::interfaces::enforcement::{
    IERC3643EnforcementDispatcher, IERC3643EnforcementDispatcherTrait,
};
use cairo_cmtat::interfaces::erc1404::IERC1404_ID;
use cairo_cmtat::interfaces::erc1643::{IERC1643Dispatcher, IERC1643DispatcherTrait};
use cairo_cmtat::interfaces::erc20_enforcement::{
    IERC3643ERC20EnforcementDispatcher, IERC3643ERC20EnforcementDispatcherTrait,
    IERC7943FungibleEnforcementDispatcher, IERC7943FungibleEnforcementDispatcherTrait,
};
use cairo_cmtat::interfaces::extra_information::{ICMTATBaseDispatcher, ICMTATBaseDispatcherTrait};
use cairo_cmtat::interfaces::mint::{IERC3643MintDispatcher, IERC3643MintDispatcherTrait};
use cairo_cmtat::interfaces::pause::{IERC3643PauseDispatcher, IERC3643PauseDispatcherTrait};
use cairo_cmtat::interfaces::rule_engine::{
    IValidationRuleEngineDispatcher, IValidationRuleEngineDispatcherTrait,
};
use cairo_cmtat::interfaces::upgrade::{IUpgradeVersionDispatcher, IUpgradeVersionDispatcherTrait};
use cairo_cmtat::mocks::rule_engine_recorder::{
    IRuleEngineRecorderDispatcher, IRuleEngineRecorderDispatcherTrait,
};
use cairo_cmtat::mocks::standard_v2_mock::{
    IStandardV2MockDispatcher, IStandardV2MockDispatcherTrait, IStandardV2MockSafeDispatcher,
    IStandardV2MockSafeDispatcherTrait,
};
use cairo_cmtat::roles::{DOCUMENT_ROLE, MINTER_ROLE};
use openzeppelin::access::accesscontrol::AccessControlComponent;
use openzeppelin::interfaces::accesscontrol::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::interfaces::erc20::{
    IERC20Dispatcher, IERC20DispatcherTrait, IERC20MetadataDispatcher,
    IERC20MetadataDispatcherTrait,
};
use openzeppelin::interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use openzeppelin::interfaces::upgrades::{IUpgradeableDispatcher, IUpgradeableDispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin_testing::{EventSpyExt, spy_events};
use snforge_std::{DeclareResultTrait, declare, get_class_hash, start_cheat_caller_address};
use starknet::{ClassHash, ContractAddress};
use crate::utils::{
    ADMIN, HOLDER, MINTER, OTHER, RECIPIENT, SPENDER, ZERO, assert_reverted_with,
    deploy_allowlist_preset, deploy_debt_preset, deploy_snapshot_preset, deploy_standard,
    standard_erc20_attributes,
};

fn version_of(token: ContractAddress) -> u64 {
    IUpgradeVersionDispatcher { contract_address: token }.initialized_version()
}

fn v2_class() -> ClassHash {
    *declare("CMTATStandardV2Mock").unwrap().contract_class().class_hash
}

/// Standard token with an engine, then upgraded to the V2 class (not migrated).
fn upgraded_standard() -> (ContractAddress, ContractAddress) {
    let engine = openzeppelin_testing::declare_and_deploy("RuleEngineRecorder", array![]);
    let token = deploy_standard(engine);
    start_cheat_caller_address(token, ADMIN);
    IUpgradeableDispatcher { contract_address: token }.upgrade(v2_class());
    (token, engine)
}

#[test]
fn presets_start_at_version_one() {
    let mut calldata = array![];
    calldata.append_serde(ADMIN);
    calldata.append_serde(standard_erc20_attributes());
    let light = openzeppelin_testing::declare_and_deploy("CMTATLight", calldata);
    assert_eq!(version_of(light), 1);
    assert_eq!(version_of(deploy_allowlist_preset()), 1);
    assert_eq!(version_of(deploy_debt_preset(ZERO)), 1);
    assert_eq!(version_of(deploy_snapshot_preset(ZERO)), 1);

    let mut spy = spy_events();
    let standard = deploy_standard(ZERO);
    assert_eq!(version_of(standard), 1);
    spy
        .assert_emitted_single(
            standard,
            UpgradeComponent::Event::Initialized(UpgradeComponent::Initialized { version: 1 }),
        );
}

/// State in every module survives `upgrade` + `migrate`, and the new class
/// keeps validating transfers through the same RuleEngine.
#[test]
fn upgrade_and_migrate_keep_storage() {
    let engine = openzeppelin_testing::declare_and_deploy("RuleEngineRecorder", array![]);
    let token = deploy_standard(engine);
    let erc20 = IERC20Dispatcher { contract_address: token };
    let access = IAccessControlDispatcher { contract_address: token };

    // State before the upgrade
    start_cheat_caller_address(token, ADMIN);
    access.grant_role(MINTER_ROLE, MINTER);
    access.grant_role(DOCUMENT_ROLE, OTHER);
    start_cheat_caller_address(token, MINTER);
    IERC3643MintDispatcher { contract_address: token }.mint(HOLDER, 1_000);
    start_cheat_caller_address(token, HOLDER);
    erc20.approve(SPENDER, 50);
    start_cheat_caller_address(token, OTHER);
    IERC1643Dispatcher { contract_address: token }.set_document('prospectus', "ipfs://p", 7);
    start_cheat_caller_address(token, ADMIN);
    IERC3643ERC20EnforcementDispatcher { contract_address: token }
        .freeze_partial_tokens(HOLDER, 300);
    IERC3643EnforcementDispatcher { contract_address: token }.set_address_frozen(OTHER, true);
    IERC3643PauseDispatcher { contract_address: token }.pause();

    // Upgrade and migrate
    let new_class = v2_class();
    let mut spy = spy_events();
    IUpgradeableDispatcher { contract_address: token }.upgrade(new_class);
    let v2 = IStandardV2MockDispatcher { contract_address: token };
    v2.migrate();
    assert_eq!(get_class_hash(token), new_class);
    assert_eq!(version_of(token), 2);
    spy
        .assert_emitted_single(
            token,
            UpgradeComponent::Event::Initialized(UpgradeComponent::Initialized { version: 2 }),
        );
    assert_eq!(v2.supply_at_migration(), 1_000);

    // Storage after
    let metadata = IERC20MetadataDispatcher { contract_address: token };
    assert_eq!(metadata.name(), "Standard Token");
    assert_eq!(metadata.symbol(), "STD");
    assert_eq!(metadata.decimals(), 0);
    assert_eq!(erc20.total_supply(), 1_000);
    assert_eq!(erc20.balance_of(HOLDER), 1_000);
    assert_eq!(erc20.allowance(HOLDER, SPENDER), 50);
    assert!(access.has_role(MINTER_ROLE, MINTER));
    assert!(!access.has_role(MINTER_ROLE, OTHER));
    assert_eq!(ICMTATBaseDispatcher { contract_address: token }.token_id(), "CH0000000000");
    let (uri, hash, _) = IERC1643Dispatcher { contract_address: token }.get_document('prospectus');
    assert_eq!(uri, "ipfs://p");
    assert_eq!(hash, 7);
    assert_eq!(
        IERC7943FungibleEnforcementDispatcher { contract_address: token }.get_frozen_tokens(HOLDER),
        300,
    );
    assert!(IERC3643EnforcementDispatcher { contract_address: token }.is_frozen(OTHER));
    assert!(IERC3643PauseDispatcher { contract_address: token }.paused());
    assert_eq!(IValidationRuleEngineDispatcher { contract_address: token }.rule_engine(), engine);
    assert!(ISRC5Dispatcher { contract_address: token }.supports_interface(IERC1404_ID));

    // The new class enforces the migrated state: 700 unfrozen tokens move, and
    // the RuleEngine sees the transfer (mint was call 1).
    IERC3643PauseDispatcher { contract_address: token }.unpause();
    start_cheat_caller_address(token, HOLDER);
    erc20.transfer(RECIPIENT, 700);
    assert_eq!(erc20.balance_of(RECIPIENT), 700);
    assert_eq!(IRuleEngineRecorderDispatcher { contract_address: engine }.call_count(), 2);
}

#[test]
#[feature("safe_dispatcher")]
fn migrate_runs_once() {
    let (token, _) = upgraded_standard();
    IStandardV2MockDispatcher { contract_address: token }.migrate();
    assert_reverted_with(
        IStandardV2MockSafeDispatcher { contract_address: token }.migrate(),
        array![INVALID_INITIALIZATION].span(),
    );
    assert_eq!(version_of(token), 2);
}

#[test]
#[feature("safe_dispatcher")]
fn migrate_requires_default_admin() {
    let (token, _) = upgraded_standard();
    start_cheat_caller_address(token, OTHER);
    assert_reverted_with(
        IStandardV2MockSafeDispatcher { contract_address: token }.migrate(),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
    assert_eq!(version_of(token), 1);
}

/// A fresh deployment of the V2 class starts at its own version, so `migrate`
/// has nothing to do there and reverts.
#[test]
#[feature("safe_dispatcher")]
fn fresh_v2_deployment_cannot_migrate() {
    let mut calldata = array![];
    calldata.append_serde(ADMIN);
    calldata.append_serde(standard_erc20_attributes());
    calldata.append_serde(crate::utils::standard_extra_information());
    calldata.append_serde(ZERO);
    let token = openzeppelin_testing::declare_and_deploy("CMTATStandardV2Mock", calldata);
    assert_eq!(version_of(token), 2);
    start_cheat_caller_address(token, ADMIN);
    assert_reverted_with(
        IStandardV2MockSafeDispatcher { contract_address: token }.migrate(),
        array![INVALID_INITIALIZATION].span(),
    );
}

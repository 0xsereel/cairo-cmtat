// SPDX-License-Identifier: MPL-2.0
// CMTATStandard preset: deployment, introspection, upgrades and ABI surface. The
// validation behaviour is covered by test_validation_matrix.

use cairo_cmtat::components::rule_engine::RuleEngineComponent;
use cairo_cmtat::interfaces::allowlist::{
    IAllowlistModuleSafeDispatcher, IAllowlistModuleSafeDispatcherTrait,
};
use cairo_cmtat::interfaces::burn::{
    IBurnFromERC20Dispatcher, IBurnFromERC20DispatcherTrait, IForcedBurnERC20SafeDispatcher,
    IForcedBurnERC20SafeDispatcherTrait,
};
use cairo_cmtat::interfaces::debt::{IDebtModuleSafeDispatcher, IDebtModuleSafeDispatcherTrait};
use cairo_cmtat::interfaces::erc1643::{Document, IERC1643Dispatcher, IERC1643DispatcherTrait};
use cairo_cmtat::interfaces::erc20_enforcement::{
    IERC3643ERC20EnforcementDispatcher, IERC3643ERC20EnforcementDispatcherTrait,
    IERC7551ERC20EnforcementDispatcher, IERC7551ERC20EnforcementDispatcherTrait,
};
use cairo_cmtat::interfaces::extra_information::{
    ICMTATBaseDispatcher, ICMTATBaseDispatcherTrait, Terms,
};
use cairo_cmtat::interfaces::mint::{IERC3643MintDispatcher, IERC3643MintDispatcherTrait};
use cairo_cmtat::interfaces::pause::IERC8343_ID;
use cairo_cmtat::interfaces::rule_engine::{
    IValidationRuleEngineDispatcher, IValidationRuleEngineDispatcherTrait,
};
use cairo_cmtat::interfaces::snapshot::{
    ISnapshotEngineModuleSafeDispatcher, ISnapshotEngineModuleSafeDispatcherTrait,
};
use cairo_cmtat::interfaces::token_attributes::{
    IERC3643VersionDispatcher, IERC3643VersionDispatcherTrait,
};
use cairo_cmtat::mocks::rule_engine_recorder::{
    IRuleEngineRecorderDispatcher, IRuleEngineRecorderDispatcherTrait,
};
use cairo_cmtat::roles::{BURNER_FROM_ROLE, DEFAULT_ADMIN_ROLE, DOCUMENT_ROLE, MINTER_ROLE};
use openzeppelin::access::accesscontrol::AccessControlComponent;
use openzeppelin::interfaces::accesscontrol::{
    IACCESSCONTROL_ID, IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::interfaces::erc20::{
    IERC20Dispatcher, IERC20DispatcherTrait, IERC20MetadataDispatcher,
    IERC20MetadataDispatcherTrait,
};
use openzeppelin::interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait, ISRC5_ID};
use openzeppelin::interfaces::upgrades::{
    IUpgradeableDispatcher, IUpgradeableDispatcherTrait, IUpgradeableSafeDispatcher,
    IUpgradeableSafeDispatcherTrait,
};
use openzeppelin_testing::{EventSpyExt, spy_events};
use snforge_std::{
    DeclareResultTrait, declare, get_class_hash, start_cheat_block_timestamp_global,
    start_cheat_caller_address,
};
use starknet::ContractAddress;
use crate::utils::{
    ADMIN, HOLDER, MINTER, OTHER, RECIPIENT, SPENDER, ZERO, assert_reverted_with, deploy_standard,
};

fn entrypoint_not_found() -> Array<felt252> {
    array!['ENTRYPOINT_NOT_FOUND', 'ENTRYPOINT_FAILED']
}

/// Standard token with HOLDER funded by MINTER.
fn setup() -> ContractAddress {
    let token = deploy_standard(ZERO);
    start_cheat_caller_address(token, ADMIN);
    IAccessControlDispatcher { contract_address: token }.grant_role(MINTER_ROLE, MINTER);
    start_cheat_caller_address(token, MINTER);
    IERC3643MintDispatcher { contract_address: token }.mint(HOLDER, 1_000);
    token
}

//
// Deployment
//

#[test]
fn constructor_sets_attributes_and_information() {
    start_cheat_block_timestamp_global(500);
    let token = deploy_standard(ZERO);
    let metadata = IERC20MetadataDispatcher { contract_address: token };
    assert_eq!(metadata.name(), "Standard Token");
    assert_eq!(metadata.symbol(), "STD");
    assert_eq!(metadata.decimals(), 0);
    let base = ICMTATBaseDispatcher { contract_address: token };
    assert_eq!(base.token_id(), "CH0000000000");
    assert_eq!(base.information(), "Standard CMTAT");
    assert_eq!(
        base.terms(),
        Terms {
            name: "Terms",
            doc: Document { uri: "ipfs://terms", document_hash: 0xabcd, last_modified: 500 },
        },
    );
    assert!(
        IAccessControlDispatcher { contract_address: token }.has_role(DEFAULT_ADMIN_ROLE, ADMIN),
    );
    assert_eq!(IERC3643VersionDispatcher { contract_address: token }.version(), "3.3.0");
    assert_eq!(IERC20Dispatcher { contract_address: token }.total_supply(), 0);
}

#[test]
fn constructor_sets_rule_engine() {
    let engine = openzeppelin_testing::declare_and_deploy("RuleEngineRecorder", array![]);
    let mut spy = spy_events();
    let token = deploy_standard(engine);
    assert_eq!(IValidationRuleEngineDispatcher { contract_address: token }.rule_engine(), engine);
    spy
        .assert_emitted_single(
            token,
            RuleEngineComponent::Event::RuleEngine(
                RuleEngineComponent::RuleEngineSet { new_rule_engine: engine },
            ),
        );
    start_cheat_caller_address(token, ADMIN);
    IERC3643MintDispatcher { contract_address: token }.mint(HOLDER, 10);
    assert_eq!(IRuleEngineRecorderDispatcher { contract_address: engine }.call_count(), 1);
}

#[test]
fn constructor_without_rule_engine() {
    let token = deploy_standard(ZERO);
    assert_eq!(IValidationRuleEngineDispatcher { contract_address: token }.rule_engine(), ZERO);
}

#[test]
fn registers_interfaces() {
    let src5 = ISRC5Dispatcher { contract_address: deploy_standard(ZERO) };
    assert!(src5.supports_interface(ISRC5_ID));
    assert!(src5.supports_interface(IACCESSCONTROL_ID));
    assert!(src5.supports_interface(IERC8343_ID));
}

//
// Upgrades
//

#[test]
fn admin_can_upgrade() {
    let token = deploy_standard(ZERO);
    let new_class = *declare("ERC20Mock").unwrap().contract_class().class_hash;
    start_cheat_caller_address(token, ADMIN);
    IUpgradeableDispatcher { contract_address: token }.upgrade(new_class);
    assert_eq!(get_class_hash(token), new_class);
}

#[test]
#[feature("safe_dispatcher")]
fn upgrade_requires_default_admin() {
    let token = deploy_standard(ZERO);
    let new_class = *declare("ERC20Mock").unwrap().contract_class().class_hash;
    start_cheat_caller_address(token, OTHER);
    assert_reverted_with(
        IUpgradeableSafeDispatcher { contract_address: token }.upgrade(new_class),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

//
// ABI surface specific to Standard
//

#[test]
fn has_erc7551_enforcement_overloads() {
    let token = setup();
    start_cheat_caller_address(token, ADMIN);
    IERC3643ERC20EnforcementDispatcher { contract_address: token }
        .freeze_partial_tokens(HOLDER, 300);
    let erc7551 = IERC7551ERC20EnforcementDispatcher { contract_address: token };
    assert_eq!(erc7551.get_active_balance_of(HOLDER), 700);
    erc7551.unfreeze_partial_tokens_with_data(HOLDER, 100, array!['ok'].span());
    assert_eq!(erc7551.get_active_balance_of(HOLDER), 800);
}

#[test]
fn has_documents() {
    let token = setup();
    start_cheat_caller_address(token, ADMIN);
    IAccessControlDispatcher { contract_address: token }.grant_role(DOCUMENT_ROLE, OTHER);
    start_cheat_caller_address(token, OTHER);
    let docs = IERC1643Dispatcher { contract_address: token };
    docs.set_document('prospectus', "ipfs://p", 1);
    assert_eq!(docs.get_all_documents(), array!['prospectus']);
}

#[test]
fn has_burn_from() {
    let token = setup();
    start_cheat_caller_address(token, ADMIN);
    IAccessControlDispatcher { contract_address: token }.grant_role(BURNER_FROM_ROLE, SPENDER);
    start_cheat_caller_address(token, HOLDER);
    IERC20Dispatcher { contract_address: token }.approve(SPENDER, 100);
    start_cheat_caller_address(token, SPENDER);
    IBurnFromERC20Dispatcher { contract_address: token }.burn_from(HOLDER, 100);
    assert_eq!(IERC20Dispatcher { contract_address: token }.balance_of(HOLDER), 900);
}

#[test]
#[feature("safe_dispatcher")]
fn has_no_light_allowlist_debt_or_snapshot_entrypoints() {
    let token = setup();
    start_cheat_caller_address(token, ADMIN);
    assert_eq!(
        IForcedBurnERC20SafeDispatcher { contract_address: token }
            .forced_burn(HOLDER, 1, array![].span())
            .unwrap_err(),
        entrypoint_not_found(),
    );
    assert_eq!(
        IAllowlistModuleSafeDispatcher { contract_address: token }
            .set_address_allowlist(RECIPIENT, true)
            .unwrap_err(),
        entrypoint_not_found(),
    );
    assert_eq!(
        IDebtModuleSafeDispatcher { contract_address: token }.credit_events().unwrap_err(),
        entrypoint_not_found(),
    );
    assert_eq!(
        ISnapshotEngineModuleSafeDispatcher { contract_address: token }
            .snapshot_engine()
            .unwrap_err(),
        entrypoint_not_found(),
    );
}

// SPDX-License-Identifier: MPL-2.0
// CMTATStandard preset: constructor, RuleEngine and the Standard-only modules.
// The ABI surface, roles and upgrades are covered for every preset by
// test_presets; validation by test_validation_matrix.

use cairo_cmtat::components::rule_engine::RuleEngineComponent;
use cairo_cmtat::interfaces::burn::{IBurnFromERC20Dispatcher, IBurnFromERC20DispatcherTrait};
use cairo_cmtat::interfaces::erc1643::{Document, IERC1643Dispatcher, IERC1643DispatcherTrait};
use cairo_cmtat::interfaces::erc20_enforcement::{
    IERC3643ERC20EnforcementDispatcher, IERC3643ERC20EnforcementDispatcherTrait,
    IERC7551ERC20EnforcementDispatcher, IERC7551ERC20EnforcementDispatcherTrait,
};
use cairo_cmtat::interfaces::extra_information::{
    ICMTATBaseDispatcher, ICMTATBaseDispatcherTrait, Terms,
};
use cairo_cmtat::interfaces::mint::{IERC3643MintDispatcher, IERC3643MintDispatcherTrait};
use cairo_cmtat::interfaces::rule_engine::{
    IValidationRuleEngineDispatcher, IValidationRuleEngineDispatcherTrait,
};
use cairo_cmtat::interfaces::token_attributes::{
    IERC3643VersionDispatcher, IERC3643VersionDispatcherTrait,
};
use cairo_cmtat::mocks::rule_engine_recorder::{
    IRuleEngineRecorderDispatcher, IRuleEngineRecorderDispatcherTrait,
};
use cairo_cmtat::roles::{BURNER_FROM_ROLE, DEFAULT_ADMIN_ROLE, DOCUMENT_ROLE, MINTER_ROLE};
use openzeppelin::interfaces::accesscontrol::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::interfaces::erc20::{
    IERC20Dispatcher, IERC20DispatcherTrait, IERC20MetadataDispatcher,
    IERC20MetadataDispatcherTrait,
};
use openzeppelin_testing::{EventSpyExt, spy_events};
use snforge_std::{start_cheat_block_timestamp_global, start_cheat_caller_address};
use starknet::ContractAddress;
use crate::utils::{ADMIN, HOLDER, MINTER, OTHER, SPENDER, ZERO, deploy_standard};

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

//
// Standard-only modules
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


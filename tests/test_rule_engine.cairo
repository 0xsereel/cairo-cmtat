// SPDX-License-Identifier: MPL-2.0
// RuleEngineComponent: engine management, `transferred` dispatch with the operator
// as spender, reentrancy guard, and engine fallbacks on the read path.

use cairo_cmtat::components::rule_engine::RuleEngineComponent;
use cairo_cmtat::errors;
use cairo_cmtat::interfaces::burn::{
    IBurnFromERC20Dispatcher, IBurnFromERC20DispatcherTrait, IERC3643BurnDispatcher,
    IERC3643BurnDispatcherTrait,
};
use cairo_cmtat::interfaces::erc1404::{
    IERC1404Dispatcher, IERC1404DispatcherTrait, IERC1404ExtendDispatcher,
    IERC1404ExtendDispatcherTrait, TRANSFER_OK, TRANSFER_REJECTED_PAUSED,
};
use cairo_cmtat::interfaces::erc20_enforcement::{
    IERC7943FungibleEnforcementDispatcher, IERC7943FungibleEnforcementDispatcherTrait,
};
use cairo_cmtat::interfaces::mint::{
    IERC3643BatchTransferDispatcher, IERC3643BatchTransferDispatcherTrait,
    IERC3643BatchTransferSafeDispatcher, IERC3643BatchTransferSafeDispatcherTrait,
    IERC3643MintDispatcher, IERC3643MintDispatcherTrait, IERC3643MintSafeDispatcher,
    IERC3643MintSafeDispatcherTrait,
};
use cairo_cmtat::interfaces::pause::{IERC3643PauseDispatcher, IERC3643PauseDispatcherTrait};
use cairo_cmtat::interfaces::rule_engine::{
    IValidationRuleEngineDispatcher, IValidationRuleEngineDispatcherTrait,
    IValidationRuleEngineSafeDispatcher, IValidationRuleEngineSafeDispatcherTrait,
};
use cairo_cmtat::interfaces::validation::{
    IERC3643ComplianceReadDispatcher, IERC3643ComplianceReadDispatcherTrait,
    IERC7551ComplianceDispatcher, IERC7551ComplianceDispatcherTrait,
};
use cairo_cmtat::mocks::rule_engine_recorder::{
    BLOCKED_CODE, IRuleEngineRecorderDispatcher, IRuleEngineRecorderDispatcherTrait, RecordedCall,
    VALUE_CODE,
};
use cairo_cmtat::roles::{BURNER_FROM_ROLE, BURNER_ROLE, BURNER_SELF_ROLE, MINTER_ROLE, PAUSER_ROLE};
use openzeppelin::access::accesscontrol::AccessControlComponent;
use openzeppelin::interfaces::accesscontrol::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::interfaces::erc20::{
    IERC20Dispatcher, IERC20DispatcherTrait, IERC20SafeDispatcher, IERC20SafeDispatcherTrait,
};
use openzeppelin::security::ReentrancyGuardComponent;
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin_testing::{EventSpyExt, spy_events};
use snforge_std::start_cheat_caller_address;
use starknet::ContractAddress;
use crate::utils::{
    ADMIN, BURNER, HOLDER, MINTER, OTHER, PAUSER, RECIPIENT, SPENDER, SUPPLY, ZERO,
    assert_reverted_with,
};

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
    access.grant_role(PAUSER_ROLE, PAUSER);
    access.grant_role(MINTER_ROLE, MINTER);
    access.grant_role(BURNER_ROLE, BURNER);
    access.grant_role(BURNER_FROM_ROLE, SPENDER);
    token
}

/// Token with the recorder set as RuleEngine.
fn setup() -> Setup {
    let token = deploy_token();
    let engine = openzeppelin_testing::declare_and_deploy("RuleEngineRecorder", array![]);
    start_cheat_caller_address(token, ADMIN);
    IValidationRuleEngineDispatcher { contract_address: token }.set_rule_engine(engine);
    Setup { token, engine }
}

fn recorder(s: Setup) -> IRuleEngineRecorderDispatcher {
    IRuleEngineRecorderDispatcher { contract_address: s.engine }
}

fn erc20(token: ContractAddress) -> IERC20Dispatcher {
    IERC20Dispatcher { contract_address: token }
}

fn assert_single_call(s: Setup, expected: RecordedCall) {
    assert_eq!(recorder(s).call_count(), 1);
    assert_eq!(recorder(s).call_at(0), expected);
}

/// Panic data of a call the recorder rejected, as seen by the token's caller:
/// the engine's revert, then one `ENTRYPOINT_FAILED` for the engine call (the
/// token's own one is added by `assert_reverted_with`).
fn rejected(from: ContractAddress, to: ContractAddress, value: u256) -> Span<felt252> {
    let mut data = array![errors::RULE_ENGINE_INVALID_TRANSFER];
    data.append_serde(from);
    data.append_serde(to);
    data.append_serde(value);
    data.append('ENTRYPOINT_FAILED');
    data.span()
}

fn with_spender(
    spender: ContractAddress, from: ContractAddress, to: ContractAddress, value: u256,
) -> RecordedCall {
    RecordedCall { with_spender: true, spender, from, to, value }
}

//
// Engine management
//

#[test]
fn set_rule_engine_stores_and_emits() {
    let token = deploy_token();
    let engine = openzeppelin_testing::declare_and_deploy("RuleEngineRecorder", array![]);
    start_cheat_caller_address(token, ADMIN);
    let mut spy = spy_events();
    let validation = IValidationRuleEngineDispatcher { contract_address: token };
    validation.set_rule_engine(engine);
    assert_eq!(validation.rule_engine(), engine);
    spy
        .assert_only_event(
            token,
            RuleEngineComponent::Event::RuleEngine(
                RuleEngineComponent::RuleEngineSet { new_rule_engine: engine },
            ),
        );
}

#[test]
fn set_rule_engine_to_zero_removes_engine() {
    let s = setup();
    IValidationRuleEngineDispatcher { contract_address: s.token }.set_rule_engine(ZERO);
    start_cheat_caller_address(s.token, HOLDER);
    erc20(s.token).transfer(RECIPIENT, 1);
    assert_eq!(recorder(s).call_count(), 0);
}

#[test]
#[feature("safe_dispatcher")]
fn set_rule_engine_rejects_same_value() {
    let s = setup();
    assert_reverted_with(
        IValidationRuleEngineSafeDispatcher { contract_address: s.token }.set_rule_engine(s.engine),
        array![errors::VALIDATION_SAME_VALUE].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn set_rule_engine_requires_default_admin() {
    let s = setup();
    start_cheat_caller_address(s.token, MINTER);
    assert_reverted_with(
        IValidationRuleEngineSafeDispatcher { contract_address: s.token }.set_rule_engine(OTHER),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

//
// `transferred` dispatch: the operator is passed as spender
//

#[test]
fn transfer_calls_erc3643_transferred_without_spender() {
    let s = setup();
    start_cheat_caller_address(s.token, HOLDER);
    erc20(s.token).transfer(RECIPIENT, 10);
    assert_single_call(
        s,
        RecordedCall { with_spender: false, spender: ZERO, from: HOLDER, to: RECIPIENT, value: 10 },
    );
}

#[test]
fn transfer_from_passes_spender() {
    let s = setup();
    start_cheat_caller_address(s.token, HOLDER);
    erc20(s.token).approve(SPENDER, 10);
    start_cheat_caller_address(s.token, SPENDER);
    erc20(s.token).transfer_from(HOLDER, RECIPIENT, 10);
    assert_single_call(s, with_spender(SPENDER, HOLDER, RECIPIENT, 10));
}

#[test]
fn mint_passes_minter_as_spender() {
    let s = setup();
    start_cheat_caller_address(s.token, MINTER);
    IERC3643MintDispatcher { contract_address: s.token }.mint(RECIPIENT, 10);
    assert_single_call(s, with_spender(MINTER, ZERO, RECIPIENT, 10));
}

#[test]
fn batch_mint_calls_engine_per_account() {
    let s = setup();
    start_cheat_caller_address(s.token, MINTER);
    IERC3643MintDispatcher { contract_address: s.token }
        .batch_mint(array![RECIPIENT, OTHER].span(), array![10, 20].span());
    assert_eq!(recorder(s).call_count(), 2);
    assert_eq!(recorder(s).call_at(0), with_spender(MINTER, ZERO, RECIPIENT, 10));
    assert_eq!(recorder(s).call_at(1), with_spender(MINTER, ZERO, OTHER, 20));
}

#[test]
fn burn_passes_burner_as_spender() {
    let s = setup();
    start_cheat_caller_address(s.token, BURNER);
    IERC3643BurnDispatcher { contract_address: s.token }.burn(HOLDER, 10);
    assert_single_call(s, with_spender(BURNER, HOLDER, ZERO, 10));
}

#[test]
fn burn_from_passes_caller_as_spender() {
    let s = setup();
    start_cheat_caller_address(s.token, HOLDER);
    erc20(s.token).approve(SPENDER, 10);
    start_cheat_caller_address(s.token, SPENDER);
    IBurnFromERC20Dispatcher { contract_address: s.token }.burn_from(HOLDER, 10);
    assert_single_call(s, with_spender(SPENDER, HOLDER, ZERO, 10));
}

#[test]
fn batch_transfer_passes_minter_as_spender_and_from() {
    let s = setup();
    start_cheat_caller_address(s.token, ADMIN);
    IAccessControlDispatcher { contract_address: s.token }.grant_role(MINTER_ROLE, HOLDER);
    start_cheat_caller_address(s.token, HOLDER);
    IERC3643BatchTransferDispatcher { contract_address: s.token }
        .batch_transfer(array![RECIPIENT].span(), array![10].span());
    assert_single_call(s, with_spender(HOLDER, HOLDER, RECIPIENT, 10));
}

#[test]
fn batch_burn_calls_engine_per_account() {
    let s = setup();
    start_cheat_caller_address(s.token, BURNER);
    IERC3643BurnDispatcher { contract_address: s.token }
        .batch_burn(array![HOLDER, HOLDER].span(), array![10, 20].span());
    assert_eq!(recorder(s).call_count(), 2);
    assert_eq!(recorder(s).call_at(0), with_spender(BURNER, HOLDER, ZERO, 10));
    assert_eq!(recorder(s).call_at(1), with_spender(BURNER, HOLDER, ZERO, 20));
}

/// Self-burn passes the holder as spender.
#[test]
fn burn_self_passes_holder_as_spender() {
    let s = setup();
    IAccessControlDispatcher { contract_address: s.token }.grant_role(BURNER_SELF_ROLE, HOLDER);
    start_cheat_caller_address(s.token, HOLDER);
    IBurnFromERC20Dispatcher { contract_address: s.token }.burn_self(10);
    assert_single_call(s, with_spender(HOLDER, HOLDER, ZERO, 10));
}

/// Forced transfers bypass every check, including the RuleEngine.
#[test]
fn forced_transfer_does_not_call_engine() {
    let s = setup();
    start_cheat_caller_address(s.token, ADMIN);
    IERC7943FungibleEnforcementDispatcher { contract_address: s.token }
        .forced_transfer(HOLDER, RECIPIENT, 10);
    assert_eq!(recorder(s).call_count(), 0);
}

#[test]
fn approve_does_not_call_engine() {
    let s = setup();
    start_cheat_caller_address(s.token, HOLDER);
    erc20(s.token).approve(SPENDER, 10);
    assert_eq!(recorder(s).call_count(), 0);
}

//
// Engine decisions and ordering
//

#[test]
#[feature("safe_dispatcher")]
fn rejecting_engine_reverts_transfer() {
    let s = setup();
    recorder(s).set_reject(true);
    start_cheat_caller_address(s.token, HOLDER);
    let result = IERC20SafeDispatcher { contract_address: s.token }.transfer(RECIPIENT, 10);
    assert_reverted_with(result, rejected(HOLDER, RECIPIENT, 10));
    assert_eq!(erc20(s.token).balance_of(RECIPIENT), 0);
}

#[test]
#[feature("safe_dispatcher")]
fn rejecting_engine_reverts_transfer_from() {
    let s = setup();
    start_cheat_caller_address(s.token, HOLDER);
    erc20(s.token).approve(SPENDER, 10);
    recorder(s).set_reject(true);
    start_cheat_caller_address(s.token, SPENDER);
    let result = IERC20SafeDispatcher { contract_address: s.token }
        .transfer_from(HOLDER, RECIPIENT, 10);
    assert_reverted_with(result, rejected(HOLDER, RECIPIENT, 10));
    assert_eq!(erc20(s.token).balance_of(RECIPIENT), 0);
    assert_eq!(erc20(s.token).allowance(HOLDER, SPENDER), 10);
}

#[test]
#[feature("safe_dispatcher")]
fn rejecting_engine_reverts_mint() {
    let s = setup();
    recorder(s).set_reject(true);
    start_cheat_caller_address(s.token, MINTER);
    let result = IERC3643MintSafeDispatcher { contract_address: s.token }.mint(RECIPIENT, 10);
    assert_reverted_with(result, rejected(ZERO, RECIPIENT, 10));
    assert_eq!(erc20(s.token).total_supply(), SUPPLY);
}

/// The first rejected item reverts the whole batch.
#[test]
#[feature("safe_dispatcher")]
fn rejecting_engine_reverts_batch_mint() {
    let s = setup();
    recorder(s).set_reject(true);
    start_cheat_caller_address(s.token, MINTER);
    let result = IERC3643MintSafeDispatcher { contract_address: s.token }
        .batch_mint(array![RECIPIENT, OTHER].span(), array![10, 20].span());
    assert_reverted_with(result, rejected(ZERO, RECIPIENT, 10));
    assert_eq!(erc20(s.token).total_supply(), SUPPLY);
}

#[test]
#[feature("safe_dispatcher")]
fn rejecting_engine_reverts_batch_transfer() {
    let s = setup();
    IAccessControlDispatcher { contract_address: s.token }.grant_role(MINTER_ROLE, HOLDER);
    recorder(s).set_reject(true);
    start_cheat_caller_address(s.token, HOLDER);
    let result = IERC3643BatchTransferSafeDispatcher { contract_address: s.token }
        .batch_transfer(array![RECIPIENT, OTHER].span(), array![10, 20].span());
    assert_reverted_with(result, rejected(HOLDER, RECIPIENT, 10));
    assert_eq!(erc20(s.token).balance_of(HOLDER), SUPPLY);
}

/// Module checks run before the engine: a paused transfer never reaches it.
#[test]
#[feature("safe_dispatcher")]
fn module_checks_run_before_engine() {
    let s = setup();
    recorder(s).set_reject(true);
    start_cheat_caller_address(s.token, PAUSER);
    IERC3643PauseDispatcher { contract_address: s.token }.pause();
    start_cheat_caller_address(s.token, HOLDER);
    assert_reverted_with(
        IERC20SafeDispatcher { contract_address: s.token }.transfer(RECIPIENT, 10),
        array![errors::ENFORCED_PAUSE].span(),
    );
}

/// An engine that reenters the token during `transferred` hits the guard.
#[test]
#[feature("safe_dispatcher")]
fn reentrant_engine_is_rejected() {
    let s = setup();
    recorder(s).set_reenter(s.token);
    start_cheat_caller_address(s.token, HOLDER);
    let result = IERC20SafeDispatcher { contract_address: s.token }.transfer(RECIPIENT, 10);
    assert_eq!(*result.unwrap_err().at(0), ReentrancyGuardComponent::Errors::REENTRANT_CALL);
    assert_eq!(erc20(s.token).balance_of(RECIPIENT), 0);
}

/// A reentrant engine cannot drain frozen tokens through `transfer_from`: the
/// whole call reverts and balances, the frozen amount and the allowance stay.
#[test]
#[feature("safe_dispatcher")]
fn reentrant_engine_cannot_move_frozen_tokens() {
    let s = setup();
    IERC7943FungibleEnforcementDispatcher { contract_address: s.token }
        .set_frozen_tokens(HOLDER, SUPPLY - 100);
    start_cheat_caller_address(s.token, HOLDER);
    erc20(s.token).approve(SPENDER, 100);
    recorder(s).set_reenter(s.token);
    start_cheat_caller_address(s.token, SPENDER);
    let result = IERC20SafeDispatcher { contract_address: s.token }
        .transfer_from(HOLDER, RECIPIENT, 100);
    assert_eq!(*result.unwrap_err().at(0), ReentrancyGuardComponent::Errors::REENTRANT_CALL);
    assert_eq!(erc20(s.token).balance_of(HOLDER), SUPPLY);
    assert_eq!(erc20(s.token).balance_of(RECIPIENT), 0);
    assert_eq!(erc20(s.token).allowance(HOLDER, SPENDER), 100);
    assert_eq!(
        IERC7943FungibleEnforcementDispatcher { contract_address: s.token }
            .get_frozen_tokens(HOLDER),
        SUPPLY - 100,
    );
}

#[test]
fn guard_is_released_after_each_call() {
    let s = setup();
    start_cheat_caller_address(s.token, HOLDER);
    erc20(s.token).transfer(RECIPIENT, 1);
    erc20(s.token).transfer(RECIPIENT, 1);
    assert_eq!(recorder(s).call_count(), 2);
}

//
// Read path falls through to the engine
//

#[test]
fn can_transfer_consults_engine() {
    let s = setup();
    let read = IERC3643ComplianceReadDispatcher { contract_address: s.token };
    let read_from = IERC7551ComplianceDispatcher { contract_address: s.token };
    assert!(read.can_transfer(HOLDER, RECIPIENT, 1));
    assert!(read_from.can_transfer_from(SPENDER, HOLDER, RECIPIENT, 1));
    recorder(s).set_can_transfer(false);
    assert!(!read.can_transfer(HOLDER, RECIPIENT, 1));
    assert!(!read_from.can_transfer_from(SPENDER, HOLDER, RECIPIENT, 1));
}

#[test]
fn detect_falls_back_to_engine_code() {
    let s = setup();
    recorder(s).set_code(9);
    let erc1404 = IERC1404Dispatcher { contract_address: s.token };
    assert_eq!(erc1404.detect_transfer_restriction(HOLDER, RECIPIENT, 1), 9);
    assert_eq!(
        IERC1404ExtendDispatcher { contract_address: s.token }
            .detect_transfer_restriction_from(SPENDER, HOLDER, RECIPIENT, 1),
        9,
    );
    assert_eq!(erc1404.message_for_transfer_restriction(9), "RecorderRestriction");
    assert_eq!(erc1404.message_for_transfer_restriction(2), "EnforcedPause");
}

#[test]
fn module_codes_take_precedence_over_engine() {
    let s = setup();
    recorder(s).set_code(9);
    start_cheat_caller_address(s.token, PAUSER);
    IERC3643PauseDispatcher { contract_address: s.token }.pause();
    assert_eq!(
        IERC1404Dispatcher { contract_address: s.token }
            .detect_transfer_restriction(HOLDER, RECIPIENT, 1),
        TRANSFER_REJECTED_PAUSED,
    );
}

/// The value reaches the engine on every read; an allowing engine leaves code 0.
#[test]
fn reads_pass_value_to_engine() {
    let s = setup();
    recorder(s).set_max_value(5);
    let read = IERC3643ComplianceReadDispatcher { contract_address: s.token };
    let erc1404 = IERC1404Dispatcher { contract_address: s.token };
    assert!(read.can_transfer(HOLDER, RECIPIENT, 5));
    assert!(!read.can_transfer(HOLDER, RECIPIENT, 6));
    assert_eq!(erc1404.detect_transfer_restriction(HOLDER, RECIPIENT, 5), TRANSFER_OK);
    assert_eq!(erc1404.detect_transfer_restriction(HOLDER, RECIPIENT, 6), VALUE_CODE);
}

/// `*_from` reads pass the spender to the engine; plain reads do not.
#[test]
fn from_reads_pass_spender_to_engine() {
    let s = setup();
    recorder(s).set_blocked(SPENDER);
    let read_from = IERC7551ComplianceDispatcher { contract_address: s.token };
    assert!(
        IERC3643ComplianceReadDispatcher { contract_address: s.token }
            .can_transfer(HOLDER, RECIPIENT, 1),
    );
    assert!(!read_from.can_transfer_from(SPENDER, HOLDER, RECIPIENT, 1));
    assert!(read_from.can_transfer_from(OTHER, HOLDER, RECIPIENT, 1));
    let extend = IERC1404ExtendDispatcher { contract_address: s.token };
    assert_eq!(
        extend.detect_transfer_restriction_from(SPENDER, HOLDER, RECIPIENT, 1), BLOCKED_CODE,
    );
    assert_eq!(extend.detect_transfer_restriction_from(OTHER, HOLDER, RECIPIENT, 1), TRANSFER_OK);
}

/// Mint-shaped (from = 0) and burn-shaped (to = 0) reads reach the engine too.
#[test]
fn mint_and_burn_shaped_reads_reach_engine() {
    let s = setup();
    recorder(s).set_blocked(ZERO);
    let read = IERC3643ComplianceReadDispatcher { contract_address: s.token };
    let erc1404 = IERC1404Dispatcher { contract_address: s.token };
    assert!(!read.can_transfer(ZERO, RECIPIENT, 1));
    assert!(!read.can_transfer(HOLDER, ZERO, 1));
    assert!(read.can_transfer(HOLDER, RECIPIENT, 1));
    assert_eq!(erc1404.detect_transfer_restriction(ZERO, RECIPIENT, 1), BLOCKED_CODE);
    assert_eq!(erc1404.detect_transfer_restriction(HOLDER, ZERO, 1), BLOCKED_CODE);
}

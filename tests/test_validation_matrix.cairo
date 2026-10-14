// SPDX-License-Identifier: MPL-2.0
// Validation matrix: every combination of pause state (none / paused / deactivated)
// and freeze state (spender, from, to frozen; partial freeze covering the whole
// balance) across every value-moving operation. Each case compares the exact
// revert data against a reference model of CMTAT v3.3.0's check order:
//
// - transfer, transfer_from, batch_transfer: active balance, paused, spender,
//   from, to (transfer passes spender = 0; batch_transfer passes the minter);
// - mint: deactivated, to (pause does not apply);
// - burn, burn_from: active balance, deactivated, from (pause and spender do not
//   apply);
// - forced_transfer (to an address or to 0): no checks;
// - forced_burn (Light): requires `from` frozen, nothing else.
//
// Holder = from, RECIPIENT = to, SPENDER = spender. The full matrix runs against
// CommonMock (CMTATBaseCommon); the Light preset runs the subset it supports;
// AllowlistMock runs it with every party listed, so the allowlist must not
// weaken any pause or freeze check.
//
// Each case also checks the read path: `can_send` / `can_receive`, `can_transfer`
// and `can_transfer_from` (true exactly when the matching transfer succeeds) and,
// on CommonMock, the ERC-1404 code from the read-order model.

use cairo_cmtat::errors;
use cairo_cmtat::interfaces::allowlist::{
    IAllowlistModuleDispatcher, IAllowlistModuleDispatcherTrait,
};
use cairo_cmtat::interfaces::burn::{
    IBurnFromERC20SafeDispatcher, IBurnFromERC20SafeDispatcherTrait, IERC3643BurnSafeDispatcher,
    IERC3643BurnSafeDispatcherTrait, IForcedBurnERC20SafeDispatcher,
    IForcedBurnERC20SafeDispatcherTrait,
};
use cairo_cmtat::interfaces::enforcement::{
    IERC3643EnforcementDispatcher, IERC3643EnforcementDispatcherTrait,
};
use cairo_cmtat::interfaces::erc1404::{
    IERC1404Dispatcher, IERC1404DispatcherTrait, IERC1404ExtendDispatcher,
    IERC1404ExtendDispatcherTrait, TRANSFER_OK, TRANSFER_REJECTED_DEACTIVATED,
    TRANSFER_REJECTED_FROM_FROZEN, TRANSFER_REJECTED_FROM_INSUFFICIENT_ACTIVE_BALANCE,
    TRANSFER_REJECTED_PAUSED, TRANSFER_REJECTED_SPENDER_FROZEN, TRANSFER_REJECTED_TO_FROZEN,
};
use cairo_cmtat::interfaces::erc20_enforcement::{
    IERC7943FungibleEnforcementDispatcher, IERC7943FungibleEnforcementDispatcherTrait,
    IERC7943FungibleEnforcementSafeDispatcher, IERC7943FungibleEnforcementSafeDispatcherTrait,
};
use cairo_cmtat::interfaces::mint::{
    IERC3643BatchTransferSafeDispatcher, IERC3643BatchTransferSafeDispatcherTrait,
    IERC3643MintDispatcher, IERC3643MintDispatcherTrait, IERC3643MintSafeDispatcher,
    IERC3643MintSafeDispatcherTrait,
};
use cairo_cmtat::interfaces::pause::{
    IERC3643PauseDispatcher, IERC3643PauseDispatcherTrait, IERC8343Dispatcher,
    IERC8343DispatcherTrait,
};
use cairo_cmtat::interfaces::validation::{
    IERC3643ComplianceReadDispatcher, IERC3643ComplianceReadDispatcherTrait,
    IERC7551ComplianceDispatcher, IERC7551ComplianceDispatcherTrait,
    IERC7943FungibleSendReceiveCheckDispatcher, IERC7943FungibleSendReceiveCheckDispatcherTrait,
};
use cairo_cmtat::roles::{
    BURNER_FROM_ROLE, BURNER_ROLE, ENFORCER_ROLE, ERC20ENFORCER_ROLE, MINTER_ROLE, PAUSER_ROLE,
};
use core::num::traits::Bounded;
use openzeppelin::interfaces::accesscontrol::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::interfaces::erc20::{
    IERC20Dispatcher, IERC20DispatcherTrait, IERC20SafeDispatcher, IERC20SafeDispatcherTrait,
};
use openzeppelin::utils::serde::SerializedAppend;
use snforge_std::start_cheat_caller_address;
use starknet::ContractAddress;
use crate::utils::{
    ADMIN, BURNER, ENFORCER, ERC20ENFORCER, HOLDER, MINTER, PAUSER, RECIPIENT, SPENDER, SUPPLY,
    ZERO,
};

const NOT_PAUSED: u8 = 0;
const PAUSED: u8 = 1;
const DEACTIVATED: u8 = 2;

// Operations
const TRANSFER: u8 = 1;
const TRANSFER_FROM: u8 = 2;
const BATCH_TRANSFER: u8 = 3;
const MINT: u8 = 4;
const BURN: u8 = 5;
const BURN_FROM: u8 = 6;
const FORCED_TRANSFER: u8 = 7;
const FORCED_TRANSFER_TO_ZERO: u8 = 8;
const FORCED_BURN: u8 = 9;

const COMMON_OPS: [u8; 8] = [
    TRANSFER, TRANSFER_FROM, BATCH_TRANSFER, MINT, BURN, BURN_FROM, FORCED_TRANSFER,
    FORCED_TRANSFER_TO_ZERO,
];
const LIGHT_OPS: [u8; 6] = [TRANSFER, TRANSFER_FROM, BATCH_TRANSFER, MINT, BURN, FORCED_BURN];
const ALLOWLIST_OPS: [u8; 7] = [
    TRANSFER, TRANSFER_FROM, BATCH_TRANSFER, MINT, BURN, FORCED_TRANSFER, FORCED_TRANSFER_TO_ZERO,
];

/// Frozen amount for the partial-freeze case: above any balance, so the active
/// balance stays 0 even after forced transfers consume frozen tokens.
const FULLY_FROZEN: u256 = 1_000_000_000_000_000_000_000;

#[derive(Copy, Drop)]
struct Case {
    pause: u8,
    spender_frozen: bool,
    from_frozen: bool,
    to_frozen: bool,
    partially_frozen: bool,
}

/// The 16 freeze combinations for one pause state; `with_partial` adds partial
/// freeze to the combinations (false for Light).
fn cases(pause: u8, with_partial: bool) -> Array<Case> {
    let mut result = array![];
    let partial_values = if with_partial {
        array![false, true]
    } else {
        array![false]
    };
    for partially_frozen in partial_values {
        for bits in 0..8_u8 {
            result
                .append(
                    Case {
                        pause,
                        spender_frozen: bits & 1 != 0,
                        from_frozen: bits & 2 != 0,
                        to_frozen: bits & 4 != 0,
                        partially_frozen,
                    },
                );
        }
    }
    result
}

//
// Reference model
//

fn cannot_send(account: ContractAddress) -> Option<Array<felt252>> {
    Option::Some(array![errors::ERC7943_CANNOT_SEND, account.into()])
}

fn cannot_receive(account: ContractAddress) -> Option<Array<felt252>> {
    Option::Some(array![errors::ERC7943_CANNOT_RECEIVE, account.into()])
}

fn insufficient_unfrozen() -> Option<Array<felt252>> {
    let mut data = array![errors::ERC7943_INSUFFICIENT_UNFROZEN_BAL];
    data.append_serde(HOLDER);
    data.append_serde(1_u256);
    data.append_serde(0_u256);
    Option::Some(data)
}

/// Expected panic data (without the trailing `ENTRYPOINT_FAILED`), or `None`.
fn expected(op: u8, case: Case) -> Option<Array<felt252>> {
    if op == FORCED_TRANSFER || op == FORCED_TRANSFER_TO_ZERO {
        return Option::None;
    }
    if op == FORCED_BURN {
        return if case.from_frozen {
            Option::None
        } else {
            Option::Some(array![errors::BURN_ENF_ADDRESS_IS_NOT_FROZEN])
        };
    }
    if op == MINT {
        if case.pause == DEACTIVATED {
            return Option::Some(array![errors::ENFORCED_DEACTIVATION]);
        }
        if case.to_frozen {
            return cannot_receive(RECIPIENT);
        }
        return Option::None;
    }
    if case.partially_frozen {
        return insufficient_unfrozen();
    }
    if op == BURN || op == BURN_FROM {
        if case.pause == DEACTIVATED {
            return Option::Some(array![errors::ENFORCED_DEACTIVATION]);
        }
        if case.from_frozen {
            return cannot_send(HOLDER);
        }
        return Option::None;
    }
    // Standard transfers
    if case.pause != NOT_PAUSED {
        return Option::Some(array![errors::ENFORCED_PAUSE]);
    }
    if op == TRANSFER_FROM && case.spender_frozen {
        return cannot_send(SPENDER);
    }
    if case.from_frozen {
        // batch_transfer's spender is the minter (HOLDER) itself.
        return cannot_send(HOLDER);
    }
    if case.to_frozen {
        return cannot_receive(RECIPIENT);
    }
    Option::None
}

/// ERC-1404 read order: active balance, deactivated, paused, from, to.
fn expected_code(case: Case) -> u8 {
    if case.partially_frozen {
        TRANSFER_REJECTED_FROM_INSUFFICIENT_ACTIVE_BALANCE
    } else if case.pause == DEACTIVATED {
        TRANSFER_REJECTED_DEACTIVATED
    } else if case.pause == PAUSED {
        TRANSFER_REJECTED_PAUSED
    } else if case.from_frozen {
        TRANSFER_REJECTED_FROM_FROZEN
    } else if case.to_frozen {
        TRANSFER_REJECTED_TO_FROZEN
    } else {
        TRANSFER_OK
    }
}

/// `detect_transfer_restriction_from` checks the spender first.
fn expected_code_from(case: Case) -> u8 {
    if case.spender_frozen {
        TRANSFER_REJECTED_SPENDER_FROZEN
    } else {
        expected_code(case)
    }
}

//
// Runner
//

fn assert_case<T, +Drop<T>>(
    result: Result<T, Array<felt252>>, expected: Option<Array<felt252>>, op: u8, case: Case,
) {
    match (result, expected) {
        (Result::Ok(_), Option::None) => {},
        (
            Result::Err(actual), Option::Some(mut expected),
        ) => {
            expected.append('ENTRYPOINT_FAILED');
            if actual != expected {
                panic_case(op, case, "wrong revert");
            }
        },
        (Result::Ok(_), Option::Some(_)) => panic_case(op, case, "expected revert, succeeded"),
        (Result::Err(_), Option::None) => panic_case(op, case, "expected success, reverted"),
    }
}

fn panic_case(op: u8, case: Case, reason: ByteArray) {
    panic!(
        "op {} pause {} spender {} from {} to {} partial {}: {}",
        op,
        case.pause,
        case.spender_frozen,
        case.from_frozen,
        case.to_frozen,
        case.partially_frozen,
        reason,
    );
}

fn check_reads(token: ContractAddress, case: Case, with_erc1404: bool) {
    let send_receive = IERC7943FungibleSendReceiveCheckDispatcher { contract_address: token };
    if send_receive.can_send(HOLDER) == case.from_frozen {
        panic_case(0, case, "can_send");
    }
    if send_receive.can_receive(RECIPIENT) == case.to_frozen {
        panic_case(0, case, "can_receive");
    }
    let can_transfer = IERC3643ComplianceReadDispatcher { contract_address: token }
        .can_transfer(HOLDER, RECIPIENT, 1);
    if can_transfer != expected(TRANSFER, case).is_none() {
        panic_case(TRANSFER, case, "can_transfer disagrees with transfer");
    }
    let can_transfer_from = IERC7551ComplianceDispatcher { contract_address: token }
        .can_transfer_from(SPENDER, HOLDER, RECIPIENT, 1);
    if can_transfer_from != expected(TRANSFER_FROM, case).is_none() {
        panic_case(TRANSFER_FROM, case, "can_transfer_from disagrees with transfer_from");
    }
    if with_erc1404 {
        let code = IERC1404Dispatcher { contract_address: token }
            .detect_transfer_restriction(HOLDER, RECIPIENT, 1);
        if code != expected_code(case) {
            panic_case(TRANSFER, case, "detect_transfer_restriction");
        }
        let code_from = IERC1404ExtendDispatcher { contract_address: token }
            .detect_transfer_restriction_from(SPENDER, HOLDER, RECIPIENT, 1);
        if code_from != expected_code_from(case) {
            panic_case(TRANSFER_FROM, case, "detect_transfer_restriction_from");
        }
        // The read and revert paths agree on whether a transfer is allowed.
        if (code == TRANSFER_OK) != can_transfer {
            panic_case(TRANSFER, case, "detect and can_transfer disagree");
        }
    }
}

fn grant(token: ContractAddress, role: felt252, account: ContractAddress) {
    start_cheat_caller_address(token, ADMIN);
    IAccessControlDispatcher { contract_address: token }.grant_role(role, account);
}

/// Grants roles, sets allowances, then applies `case`. HOLDER is also a minter so
/// batch_transfer moves HOLDER's tokens.
fn apply_case(token: ContractAddress, case: Case) {
    start_cheat_caller_address(token, HOLDER);
    IERC20Dispatcher { contract_address: token }.approve(SPENDER, Bounded::MAX);
    if case.partially_frozen {
        start_cheat_caller_address(token, ERC20ENFORCER);
        IERC7943FungibleEnforcementDispatcher { contract_address: token }
            .set_frozen_tokens(HOLDER, FULLY_FROZEN);
    }
    start_cheat_caller_address(token, ENFORCER);
    let enforcement = IERC3643EnforcementDispatcher { contract_address: token };
    if case.spender_frozen {
        enforcement.set_address_frozen(SPENDER, true);
    }
    if case.from_frozen {
        enforcement.set_address_frozen(HOLDER, true);
    }
    if case.to_frozen {
        enforcement.set_address_frozen(RECIPIENT, true);
    }
    if case.pause != NOT_PAUSED {
        start_cheat_caller_address(token, PAUSER);
        IERC3643PauseDispatcher { contract_address: token }.pause();
    }
    if case.pause == DEACTIVATED {
        start_cheat_caller_address(token, ADMIN);
        IERC8343Dispatcher { contract_address: token }.deactivate_contract();
    }
}

fn grant_common_roles(token: ContractAddress) {
    grant(token, PAUSER_ROLE, PAUSER);
    grant(token, ENFORCER_ROLE, ENFORCER);
    grant(token, ERC20ENFORCER_ROLE, ERC20ENFORCER);
    grant(token, MINTER_ROLE, MINTER);
    grant(token, MINTER_ROLE, HOLDER);
    grant(token, BURNER_ROLE, BURNER);
}

#[feature("safe_dispatcher")]
fn run_op(token: ContractAddress, op: u8, case: Case) {
    let expected = expected(op, case);
    if op == TRANSFER {
        start_cheat_caller_address(token, HOLDER);
        let result = IERC20SafeDispatcher { contract_address: token }.transfer(RECIPIENT, 1);
        assert_case(result, expected, op, case);
    } else if op == TRANSFER_FROM {
        start_cheat_caller_address(token, SPENDER);
        let result = IERC20SafeDispatcher { contract_address: token }
            .transfer_from(HOLDER, RECIPIENT, 1);
        assert_case(result, expected, op, case);
    } else if op == BATCH_TRANSFER {
        start_cheat_caller_address(token, HOLDER);
        let result = IERC3643BatchTransferSafeDispatcher { contract_address: token }
            .batch_transfer(array![RECIPIENT].span(), array![1].span());
        assert_case(result, expected, op, case);
    } else if op == MINT {
        start_cheat_caller_address(token, MINTER);
        let result = IERC3643MintSafeDispatcher { contract_address: token }.mint(RECIPIENT, 1);
        assert_case(result, expected, op, case);
    } else if op == BURN {
        start_cheat_caller_address(token, BURNER);
        let result = IERC3643BurnSafeDispatcher { contract_address: token }.burn(HOLDER, 1);
        assert_case(result, expected, op, case);
    } else if op == BURN_FROM {
        start_cheat_caller_address(token, SPENDER);
        let result = IBurnFromERC20SafeDispatcher { contract_address: token }.burn_from(HOLDER, 1);
        assert_case(result, expected, op, case);
    } else if op == FORCED_TRANSFER {
        start_cheat_caller_address(token, ADMIN);
        let result = IERC7943FungibleEnforcementSafeDispatcher { contract_address: token }
            .forced_transfer(HOLDER, RECIPIENT, 1);
        assert_case(result, expected, op, case);
    } else if op == FORCED_TRANSFER_TO_ZERO {
        start_cheat_caller_address(token, ADMIN);
        let result = IERC7943FungibleEnforcementSafeDispatcher { contract_address: token }
            .forced_transfer(HOLDER, ZERO, 1);
        assert_case(result, expected, op, case);
    } else if op == FORCED_BURN {
        start_cheat_caller_address(token, ADMIN);
        let result = IForcedBurnERC20SafeDispatcher { contract_address: token }
            .forced_burn(HOLDER, 1, array![].span());
        assert_case(result, expected, op, case);
    }
}

//
// CommonMock (CMTATBaseCommon): full matrix
//

fn deploy_common() -> ContractAddress {
    let mut calldata = array![];
    calldata.append_serde(18_u8);
    calldata.append_serde(SUPPLY);
    calldata.append_serde(HOLDER);
    calldata.append_serde(ADMIN);
    let token = openzeppelin_testing::declare_and_deploy("CommonMock", calldata);
    grant_common_roles(token);
    grant(token, BURNER_FROM_ROLE, SPENDER);
    token
}

fn run_common(pause: u8) {
    for case in cases(pause, true) {
        let token = deploy_common();
        apply_case(token, case);
        check_reads(token, case, true);
        for op in COMMON_OPS.span() {
            run_op(token, *op, case);
        }
    }
}

#[test]
fn common_matrix_not_paused() {
    run_common(NOT_PAUSED);
}

#[test]
fn common_matrix_paused() {
    run_common(PAUSED);
}

#[test]
fn common_matrix_deactivated() {
    run_common(DEACTIVATED);
}

//
// CMTATLight (CMTATBaseCore): no partial freeze, burn-from or forced transfer
//

fn deploy_light() -> ContractAddress {
    let mut calldata = array![];
    calldata.append_serde(ADMIN);
    let name: ByteArray = "Light";
    calldata.append_serde(name);
    let symbol: ByteArray = "LGT";
    calldata.append_serde(symbol);
    calldata.append_serde(0_u8);
    let token = openzeppelin_testing::declare_and_deploy("CMTATLight", calldata);
    grant_common_roles(token);
    start_cheat_caller_address(token, MINTER);
    IERC3643MintDispatcher { contract_address: token }.mint(HOLDER, SUPPLY);
    token
}

fn run_light(pause: u8) {
    for case in cases(pause, false) {
        let token = deploy_light();
        apply_case(token, case);
        check_reads(token, case, false);
        for op in LIGHT_OPS.span() {
            run_op(token, *op, case);
        }
    }
}

#[test]
fn light_matrix_not_paused() {
    run_light(NOT_PAUSED);
}

#[test]
fn light_matrix_paused() {
    run_light(PAUSED);
}

#[test]
fn light_matrix_deactivated() {
    run_light(DEACTIVATED);
}

//
// AllowlistMock (CMTATBaseAllowlist), every party listed: identical to CommonMock
//

fn deploy_allowlist() -> ContractAddress {
    let mut calldata = array![];
    calldata.append_serde(18_u8);
    calldata.append_serde(SUPPLY);
    calldata.append_serde(HOLDER);
    calldata.append_serde(ADMIN);
    let token = openzeppelin_testing::declare_and_deploy("AllowlistMock", calldata);
    grant_common_roles(token);
    start_cheat_caller_address(token, ADMIN);
    IAllowlistModuleDispatcher { contract_address: token }
        .batch_set_address_allowlist(
            array![HOLDER, RECIPIENT, SPENDER].span(), array![true, true, true].span(),
        );
    token
}

fn run_allowlist(pause: u8) {
    for case in cases(pause, true) {
        let token = deploy_allowlist();
        apply_case(token, case);
        check_reads(token, case, false);
        for op in ALLOWLIST_OPS.span() {
            run_op(token, *op, case);
        }
    }
}

#[test]
fn allowlist_matrix_not_paused() {
    run_allowlist(NOT_PAUSED);
}

#[test]
fn allowlist_matrix_paused() {
    run_allowlist(PAUSED);
}

#[test]
fn allowlist_matrix_deactivated() {
    run_allowlist(DEACTIVATED);
}

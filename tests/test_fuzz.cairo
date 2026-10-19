// SPDX-License-Identifier: MPL-2.0
// Fuzz tests for partial freeze and balance arithmetic on the Standard preset.
// Inputs are reduced so that frozen and transferred amounts stay within the
// balance, except where a property is about exceeding it.

use cairo_cmtat::errors;
use cairo_cmtat::interfaces::burn::{IERC3643BurnSafeDispatcher, IERC3643BurnSafeDispatcherTrait};
use cairo_cmtat::interfaces::erc1404::{
    IERC1404Dispatcher, IERC1404DispatcherTrait, TRANSFER_OK,
    TRANSFER_REJECTED_FROM_INSUFFICIENT_ACTIVE_BALANCE,
};
use cairo_cmtat::interfaces::erc20_enforcement::{
    IERC3643ERC20EnforcementDispatcher, IERC3643ERC20EnforcementDispatcherTrait,
    IERC3643ERC20EnforcementSafeDispatcher, IERC3643ERC20EnforcementSafeDispatcherTrait,
    IERC7551ERC20EnforcementDispatcher, IERC7551ERC20EnforcementDispatcherTrait,
    IERC7943FungibleEnforcementDispatcher, IERC7943FungibleEnforcementDispatcherTrait,
};
use cairo_cmtat::interfaces::mint::{IERC3643MintDispatcher, IERC3643MintDispatcherTrait};
use openzeppelin::interfaces::erc20::{
    IERC20Dispatcher, IERC20DispatcherTrait, IERC20SafeDispatcher, IERC20SafeDispatcherTrait,
};
use openzeppelin::utils::serde::SerializedAppend;
use snforge_std::start_cheat_caller_address;
use starknet::ContractAddress;
use crate::utils::{ADMIN, HOLDER, RECIPIENT, ZERO, assert_reverted_with, deploy_standard};

/// Standard token, ADMIN (all roles) as caller, `balance` minted to HOLDER and
/// `frozen` of it frozen.
fn setup(balance: u256, frozen: u256) -> ContractAddress {
    let token = deploy_standard(ZERO);
    start_cheat_caller_address(token, ADMIN);
    if balance > 0 {
        IERC3643MintDispatcher { contract_address: token }.mint(HOLDER, balance);
    }
    if frozen > 0 {
        IERC3643ERC20EnforcementDispatcher { contract_address: token }
            .freeze_partial_tokens(HOLDER, frozen);
    }
    token
}

/// `seed` reduced to `0..=max`. Amounts derive from u128 inputs, so `max + 1`
/// cannot overflow.
fn upto(seed: u128, max: u256) -> u256 {
    let seed: u256 = seed.into();
    seed % (max + 1)
}

fn frozen_of(token: ContractAddress) -> u256 {
    IERC7943FungibleEnforcementDispatcher { contract_address: token }.get_frozen_tokens(HOLDER)
}

fn active_of(token: ContractAddress) -> u256 {
    IERC7551ERC20EnforcementDispatcher { contract_address: token }.get_active_balance_of(HOLDER)
}

fn insufficient(value: u256, active: u256) -> Array<felt252> {
    let mut data = array![errors::ERC7943_INSUFFICIENT_UNFROZEN_BAL];
    data.append_serde(HOLDER);
    data.append_serde(value);
    data.append_serde(active);
    data
}

/// A transfer succeeds iff it fits in the active balance; frozen tokens never
/// move, and ERC-1404 agrees with the outcome.
#[test]
#[fuzzer(runs: 64)]
#[feature("safe_dispatcher")]
fn transfer_is_limited_to_active_balance(balance: u128, frozen_seed: u128, value_seed: u128) {
    let balance: u256 = balance.into();
    let frozen = upto(frozen_seed, balance);
    let value = upto(value_seed, balance);
    let token = setup(balance, frozen);
    let active = balance - frozen;
    assert_eq!(frozen_of(token), frozen);
    assert_eq!(active_of(token), active);

    let fits = frozen == 0 || value <= active;
    let code = IERC1404Dispatcher { contract_address: token }
        .detect_transfer_restriction(HOLDER, RECIPIENT, value);
    let expected_code = if fits {
        TRANSFER_OK
    } else {
        TRANSFER_REJECTED_FROM_INSUFFICIENT_ACTIVE_BALANCE
    };
    assert_eq!(code, expected_code);

    start_cheat_caller_address(token, HOLDER);
    let result = IERC20SafeDispatcher { contract_address: token }.transfer(RECIPIENT, value);
    let erc20 = IERC20Dispatcher { contract_address: token };
    if fits {
        assert!(result.unwrap());
        assert_eq!(erc20.balance_of(HOLDER), balance - value);
        assert_eq!(erc20.balance_of(RECIPIENT), value);
    } else {
        assert_reverted_with(result, insufficient(value, active).span());
        assert_eq!(erc20.balance_of(HOLDER), balance);
    }
    assert_eq!(frozen_of(token), frozen);
    assert_eq!(erc20.total_supply(), balance);
}

/// `set_frozen_tokens` may exceed the balance; the active balance saturates at
/// zero.
#[test]
#[fuzzer(runs: 64)]
fn active_balance_saturates(balance: u128, frozen: u128) {
    let balance: u256 = balance.into();
    let frozen: u256 = frozen.into();
    let token = setup(balance, 0);
    if frozen > 0 {
        IERC7943FungibleEnforcementDispatcher { contract_address: token }
            .set_frozen_tokens(HOLDER, frozen);
    }
    assert_eq!(frozen_of(token), frozen);
    let expected = if frozen >= balance {
        0
    } else {
        balance - frozen
    };
    assert_eq!(active_of(token), expected);
}

/// Unfreezing up to the frozen amount always works; more reverts.
#[test]
#[fuzzer(runs: 64)]
#[feature("safe_dispatcher")]
fn unfreeze_is_bounded_by_frozen(balance: u128, frozen_seed: u128, unfreeze_seed: u128) {
    let balance: u256 = balance.into();
    let frozen = upto(frozen_seed, balance);
    let unfreeze = upto(unfreeze_seed, frozen);
    let token = setup(balance, frozen);
    let enforcement = IERC3643ERC20EnforcementDispatcher { contract_address: token };
    if unfreeze > 0 {
        enforcement.unfreeze_partial_tokens(HOLDER, unfreeze);
    }
    assert_eq!(frozen_of(token), frozen - unfreeze);
    assert_eq!(active_of(token), balance - frozen + unfreeze);
    assert_reverted_with(
        IERC3643ERC20EnforcementSafeDispatcher { contract_address: token }
            .unfreeze_partial_tokens(HOLDER, frozen - unfreeze + 1),
        array![errors::ERC20ENF_VALUE_EXCEEDS_FROZEN_BAL].span(),
    );
}

/// Forced transfer (and forced burn via `to == 0`) unfreezes only the
/// shortfall: afterwards frozen is `min(frozen, balance - value)`.
#[test]
#[fuzzer(runs: 64)]
fn forced_transfer_unfreezes_only_shortfall(
    balance: u128, frozen_seed: u128, value_seed: u128, to_zero: u8,
) {
    let balance: u256 = balance.into();
    let frozen = upto(frozen_seed, balance);
    let value = upto(value_seed, balance);
    let token = setup(balance, frozen);
    let to = if to_zero % 2 == 0 {
        RECIPIENT
    } else {
        ZERO
    };
    IERC7943FungibleEnforcementDispatcher { contract_address: token }
        .forced_transfer(HOLDER, to, value);

    let remaining = balance - value;
    let expected_frozen = if frozen < remaining {
        frozen
    } else {
        remaining
    };
    assert_eq!(frozen_of(token), expected_frozen);
    let erc20 = IERC20Dispatcher { contract_address: token };
    assert_eq!(erc20.balance_of(HOLDER), remaining);
    if to == ZERO {
        assert_eq!(erc20.total_supply(), remaining);
    } else {
        assert_eq!(erc20.balance_of(RECIPIENT), value);
        assert_eq!(erc20.total_supply(), balance);
    }
}

/// A standard burn is limited to the active balance and never unfreezes.
#[test]
#[fuzzer(runs: 64)]
#[feature("safe_dispatcher")]
fn burn_is_limited_to_active_balance(balance: u128, frozen_seed: u128, value_seed: u128) {
    let balance: u256 = balance.into();
    let frozen = upto(frozen_seed, balance);
    let value = upto(value_seed, balance);
    let token = setup(balance, frozen);
    let active = balance - frozen;
    let result = IERC3643BurnSafeDispatcher { contract_address: token }.burn(HOLDER, value);
    let erc20 = IERC20Dispatcher { contract_address: token };
    if frozen == 0 || value <= active {
        result.unwrap();
        assert_eq!(erc20.total_supply(), balance - value);
    } else {
        assert_reverted_with(result, insufficient(value, active).span());
        assert_eq!(erc20.total_supply(), balance);
    }
    assert_eq!(frozen_of(token), frozen);
}

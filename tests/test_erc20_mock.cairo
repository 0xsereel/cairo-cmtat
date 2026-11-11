// SPDX-License-Identifier: MPL-2.0
// Smoke tests for the harness: deployment, event queue and revert assertions.

use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
use openzeppelin::interfaces::accesscontrol::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::interfaces::erc20::{
    IERC20Dispatcher, IERC20DispatcherTrait, IERC20SafeDispatcher, IERC20SafeDispatcherTrait,
};
use openzeppelin::token::erc20::ERC20Component;
use openzeppelin_testing::{EventSpyExt, spy_events};
use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
use crate::utils::{
    ADMIN, HOLDER, OTHER, RECIPIENT, SUPPLY, assert_reverted_with, deploy_erc20_mock,
};

#[test]
fn deploy_mints_supply_and_grants_admin() {
    let token = deploy_erc20_mock();
    let erc20 = IERC20Dispatcher { contract_address: token };
    let access = IAccessControlDispatcher { contract_address: token };

    assert_eq!(erc20.total_supply(), SUPPLY);
    assert_eq!(erc20.balance_of(HOLDER), SUPPLY);
    assert!(access.has_role(DEFAULT_ADMIN_ROLE, ADMIN));
    assert!(!access.has_role(DEFAULT_ADMIN_ROLE, OTHER));
}

#[test]
fn transfer_emits_event() {
    let token = deploy_erc20_mock();
    let erc20 = IERC20Dispatcher { contract_address: token };
    let mut spy = spy_events();

    start_cheat_caller_address(token, HOLDER);
    erc20.transfer(RECIPIENT, 100);
    stop_cheat_caller_address(token);

    spy
        .assert_only_event(
            token,
            ERC20Component::Event::Transfer(
                ERC20Component::Transfer { from: HOLDER, to: RECIPIENT, value: 100 },
            ),
        );
    assert_eq!(erc20.balance_of(RECIPIENT), 100);
}

#[test]
#[feature("safe_dispatcher")]
fn assert_reverted_with_matches_panic_data() {
    let token = deploy_erc20_mock();
    let erc20 = IERC20SafeDispatcher { contract_address: token };

    start_cheat_caller_address(token, OTHER);
    assert_reverted_with(
        erc20.transfer(RECIPIENT, 1), array!['ERC20: insufficient balance'].span(),
    );
}

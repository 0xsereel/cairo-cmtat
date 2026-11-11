// SPDX-License-Identifier: MPL-2.0
// ForcedBurnComponent (Light preset's forced burn).

use cairo_cmtat::components::forced_burn::ForcedBurnComponent;
use cairo_cmtat::errors;
use cairo_cmtat::interfaces::burn::{
    IForcedBurnERC20Dispatcher, IForcedBurnERC20DispatcherTrait, IForcedBurnERC20SafeDispatcher,
    IForcedBurnERC20SafeDispatcherTrait,
};
use cairo_cmtat::interfaces::enforcement::{
    IERC3643EnforcementDispatcher, IERC3643EnforcementDispatcherTrait,
};
use cairo_cmtat::roles::ENFORCER_ROLE;
use openzeppelin::access::accesscontrol::AccessControlComponent;
use openzeppelin::interfaces::accesscontrol::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::token::erc20::ERC20Component;
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin_testing::{EventSpyExt, spy_events};
use snforge_std::start_cheat_caller_address;
use starknet::ContractAddress;
use crate::utils::{ADMIN, ENFORCER, HOLDER, SUPPLY, ZERO, assert_reverted_with};

fn setup() -> ContractAddress {
    let mut calldata = array![];
    calldata.append_serde(SUPPLY);
    calldata.append_serde(HOLDER);
    calldata.append_serde(ADMIN);
    let token = openzeppelin_testing::declare_and_deploy("ForcedBurnMock", calldata);
    start_cheat_caller_address(token, ADMIN);
    IAccessControlDispatcher { contract_address: token }.grant_role(ENFORCER_ROLE, ENFORCER);
    token
}

fn setup_frozen() -> ContractAddress {
    let token = setup();
    start_cheat_caller_address(token, ENFORCER);
    IERC3643EnforcementDispatcher { contract_address: token }.set_address_frozen(HOLDER, true);
    start_cheat_caller_address(token, ADMIN);
    token
}

#[test]
fn forced_burn_burns_frozen_account_and_emits_forced_transfer() {
    let token = setup_frozen();
    let data = array!['seizure'].span();
    let mut spy = spy_events();
    IForcedBurnERC20Dispatcher { contract_address: token }.forced_burn(HOLDER, 100, data);
    assert_eq!(IERC20Dispatcher { contract_address: token }.balance_of(HOLDER), SUPPLY - 100);
    spy
        .assert_emitted_single(
            token,
            ERC20Component::Event::Transfer(
                ERC20Component::Transfer { from: HOLDER, to: ZERO, value: 100 },
            ),
        );
    spy
        .assert_only_event(
            token,
            ForcedBurnComponent::Event::ForcedTransfer(
                ForcedBurnComponent::ForcedTransfer {
                    operator: ADMIN, from: HOLDER, to: ZERO, value: 100, data,
                },
            ),
        );
}

#[test]
#[feature("safe_dispatcher")]
fn forced_burn_requires_frozen_account() {
    let token = setup();
    assert_reverted_with(
        IForcedBurnERC20SafeDispatcher { contract_address: token }
            .forced_burn(HOLDER, 1, array![].span()),
        array![errors::BURN_ENF_ADDRESS_IS_NOT_FROZEN].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn forced_burn_requires_default_admin() {
    let token = setup_frozen();
    start_cheat_caller_address(token, ENFORCER);
    assert_reverted_with(
        IForcedBurnERC20SafeDispatcher { contract_address: token }
            .forced_burn(HOLDER, 1, array![].span()),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

// SPDX-License-Identifier: MPL-2.0
// CMTATLight preset: deployment, introspection, upgrades and ABI surface. The
// validation behaviour is covered by test_validation_matrix.

use cairo_cmtat::interfaces::burn::{
    IBurnFromERC20SafeDispatcher, IBurnFromERC20SafeDispatcherTrait,
};
use cairo_cmtat::interfaces::erc20_enforcement::{
    IERC7943FungibleEnforcementSafeDispatcher, IERC7943FungibleEnforcementSafeDispatcherTrait,
};
use cairo_cmtat::interfaces::extra_information::{
    ICMTATBaseSafeDispatcher, ICMTATBaseSafeDispatcherTrait,
};
use cairo_cmtat::interfaces::token_attributes::{
    IERC3643VersionDispatcher, IERC3643VersionDispatcherTrait,
};
use cairo_cmtat::roles::DEFAULT_ADMIN_ROLE;
use openzeppelin::access::accesscontrol::AccessControlComponent;
use openzeppelin::interfaces::accesscontrol::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::interfaces::erc20::{IERC20MetadataDispatcher, IERC20MetadataDispatcherTrait};
use openzeppelin::interfaces::upgrades::{
    IUpgradeableDispatcher, IUpgradeableDispatcherTrait, IUpgradeableSafeDispatcher,
    IUpgradeableSafeDispatcherTrait,
};
use openzeppelin::utils::serde::SerializedAppend;
use snforge_std::{DeclareResultTrait, declare, get_class_hash, start_cheat_caller_address};
use starknet::ContractAddress;
use crate::utils::{ADMIN, HOLDER, OTHER, RECIPIENT, assert_reverted_with};

fn deploy() -> ContractAddress {
    let mut calldata = array![];
    calldata.append_serde(ADMIN);
    let name: ByteArray = "Light Token";
    let symbol: ByteArray = "LGT";
    calldata.append_serde(name);
    calldata.append_serde(symbol);
    calldata.append_serde(0_u8);
    openzeppelin_testing::declare_and_deploy("CMTATLight", calldata)
}

fn entrypoint_not_found() -> Array<felt252> {
    array!['ENTRYPOINT_NOT_FOUND', 'ENTRYPOINT_FAILED']
}

#[test]
fn constructor_sets_attributes_and_admin() {
    let token = deploy();
    let metadata = IERC20MetadataDispatcher { contract_address: token };
    assert_eq!(metadata.name(), "Light Token");
    assert_eq!(metadata.symbol(), "LGT");
    assert_eq!(metadata.decimals(), 0);
    assert!(
        IAccessControlDispatcher { contract_address: token }.has_role(DEFAULT_ADMIN_ROLE, ADMIN),
    );
    assert_eq!(IERC3643VersionDispatcher { contract_address: token }.version(), "3.3.0");
}

//
// Upgrades
//

#[test]
fn admin_can_upgrade() {
    let token = deploy();
    let new_class = *declare("ERC20Mock").unwrap().contract_class().class_hash;
    start_cheat_caller_address(token, ADMIN);
    IUpgradeableDispatcher { contract_address: token }.upgrade(new_class);
    assert_eq!(get_class_hash(token), new_class);
}

#[test]
#[feature("safe_dispatcher")]
fn upgrade_requires_default_admin() {
    let token = deploy();
    let new_class = *declare("ERC20Mock").unwrap().contract_class().class_hash;
    start_cheat_caller_address(token, OTHER);
    assert_reverted_with(
        IUpgradeableSafeDispatcher { contract_address: token }.upgrade(new_class),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

//
// Light omits partial freeze, forced transfer, burn-from and extra information
//

#[test]
#[feature("safe_dispatcher")]
fn has_no_forced_transfer() {
    let token = deploy();
    start_cheat_caller_address(token, ADMIN);
    let result = IERC7943FungibleEnforcementSafeDispatcher { contract_address: token }
        .forced_transfer(HOLDER, RECIPIENT, 1);
    assert_eq!(result.unwrap_err(), entrypoint_not_found());
}

#[test]
#[feature("safe_dispatcher")]
fn has_no_burn_from() {
    let token = deploy();
    start_cheat_caller_address(token, ADMIN);
    let result = IBurnFromERC20SafeDispatcher { contract_address: token }.burn_from(HOLDER, 1);
    assert_eq!(result.unwrap_err(), entrypoint_not_found());
}

#[test]
#[feature("safe_dispatcher")]
fn has_no_extra_information() {
    let token = deploy();
    let result = ICMTATBaseSafeDispatcher { contract_address: token }.token_id();
    assert_eq!(result.unwrap_err(), entrypoint_not_found());
}

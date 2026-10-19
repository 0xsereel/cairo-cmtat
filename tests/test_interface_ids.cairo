// SPDX-License-Identifier: MPL-2.0
// SNIP-5 interface ids: each constant matches its extended selectors, and each
// preset reports exactly the set its CMTAT base reports through ERC-165.

use cairo_cmtat::interfaces::erc1404::{IERC1404_EXTEND_ID, IERC1404_ID};
use cairo_cmtat::interfaces::erc1643::IERC1643_ID;
use cairo_cmtat::interfaces::erc20_enforcement::IERC7943_ID;
use cairo_cmtat::interfaces::mint::IERC5679_ID;
use cairo_cmtat::interfaces::pause::IERC8343_ID;
use openzeppelin::interfaces::accesscontrol::IACCESSCONTROL_ID;
use openzeppelin::interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait, ISRC5_ID};
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ContractAddress;
use crate::utils::{
    ADMIN, ZERO, deploy_allowlist_preset, deploy_debt_preset, deploy_snapshot_preset,
    deploy_standard,
};

fn xor(selectors: Span<felt252>) -> u256 {
    let mut acc: u256 = 0;
    for selector in selectors {
        let value: u256 = (*selector).into();
        acc = acc ^ value;
    }
    acc
}

//
// Id derivation
//

#[test]
fn erc5679_id_matches_extended_selectors() {
    let expected = xor(
        array![
            selector!("mint_with_data(ContractAddress,(u128,u128),(@Array<felt252>))"),
            selector!("burn_with_data(ContractAddress,(u128,u128),(@Array<felt252>))"),
        ]
            .span(),
    );
    assert_eq!(IERC5679_ID.into(), expected);
}

#[test]
fn erc7943_id_matches_extended_selectors() {
    let expected = xor(
        array![
            selector!("get_frozen_tokens(ContractAddress)->(u128,u128)"),
            selector!("set_frozen_tokens(ContractAddress,(u128,u128))->E((),())"),
            selector!("forced_transfer(ContractAddress,ContractAddress,(u128,u128))->E((),())"),
            selector!("can_send(ContractAddress)->E((),())"),
            selector!("can_receive(ContractAddress)->E((),())"),
            selector!("can_transfer(ContractAddress,ContractAddress,(u128,u128))->E((),())"),
        ]
            .span(),
    );
    assert_eq!(IERC7943_ID.into(), expected);
}

#[test]
fn erc1643_id_matches_extended_selectors() {
    let expected = xor(
        array![
            selector!("get_document(felt252)->((Array<bytes31>,felt252,u32),(u128,u128),u64)"),
            selector!("get_all_documents()->Array<felt252>"),
            selector!("set_document(felt252,(Array<bytes31>,felt252,u32),(u128,u128))"),
            selector!("remove_document(felt252)"),
        ]
            .span(),
    );
    assert_eq!(IERC1643_ID.into(), expected);
}

#[test]
fn erc1404_ids_match_extended_selectors() {
    let erc1404 = xor(
        array![
            selector!(
                "detect_transfer_restriction(ContractAddress,ContractAddress,(u128,u128))->u8",
            ),
            selector!("message_for_transfer_restriction(u8)->(Array<bytes31>,felt252,u32)"),
        ]
            .span(),
    );
    assert_eq!(IERC1404_ID.into(), erc1404);
    let from: u256 = selector!(
        "detect_transfer_restriction_from(ContractAddress,ContractAddress,ContractAddress,(u128,u128))->u8",
    )
        .into();
    assert_eq!(IERC1404_EXTEND_ID.into(), erc1404 ^ from);
}

//
// Registration per preset
//

/// Asserts that `token` supports exactly the ids in `expected` among all ids
/// defined by OpenZeppelin and this crate.
fn assert_supports_exactly(token: ContractAddress, expected: Span<felt252>) {
    let src5 = ISRC5Dispatcher { contract_address: token };
    let all = array![
        ISRC5_ID, IACCESSCONTROL_ID, IERC8343_ID, IERC5679_ID, IERC7943_ID, IERC1643_ID,
        IERC1404_ID, IERC1404_EXTEND_ID,
    ];
    for id in all {
        let mut wanted = false;
        for e in expected {
            if *e == id {
                wanted = true;
            }
        }
        assert_eq!(src5.supports_interface(id), wanted, "interface {}", id);
    }
}

/// CMTATBaseCore: ERC-5679, ERC-8343 and AccessControl. No ERC-7943 (Core has no
/// partial freeze) and no ERC-1643.
#[test]
fn light_interfaces() {
    let mut calldata = array![];
    calldata.append_serde(ADMIN);
    calldata.append_serde(crate::utils::standard_erc20_attributes());
    let token = openzeppelin_testing::declare_and_deploy("CMTATLight", calldata);
    assert_supports_exactly(
        token, array![ISRC5_ID, IACCESSCONTROL_ID, IERC8343_ID, IERC5679_ID].span(),
    );
}

fn common_ids() -> Array<felt252> {
    array![ISRC5_ID, IACCESSCONTROL_ID, IERC8343_ID, IERC5679_ID, IERC7943_ID, IERC1643_ID]
}

/// CMTATBaseAccessControl: the Core set plus ERC-7943 and ERC-1643.
#[test]
fn allowlist_interfaces() {
    assert_supports_exactly(deploy_allowlist_preset(), common_ids().span());
}

/// CMTATBaseDebt sits on CMTATBaseRuleEngine, below CMTATBaseERC1404.
#[test]
fn debt_interfaces() {
    assert_supports_exactly(deploy_debt_preset(ZERO), common_ids().span());
}

/// CMTATBaseERC1404: the common set plus ERC-1404 and IERC1404Extend.
#[test]
fn standard_interfaces() {
    let mut expected = common_ids();
    expected.append(IERC1404_ID);
    expected.append(IERC1404_EXTEND_ID);
    assert_supports_exactly(deploy_standard(ZERO), expected.span());
}

#[test]
fn snapshot_interfaces() {
    let mut expected = common_ids();
    expected.append(IERC1404_ID);
    expected.append(IERC1404_EXTEND_ID);
    assert_supports_exactly(deploy_snapshot_preset(ZERO), expected.span());
}

// SPDX-License-Identifier: MPL-2.0
// DocumentsComponent: ERC-1643 documents stored in the token.

use cairo_cmtat::components::documents::DocumentsComponent;
use cairo_cmtat::errors;
use cairo_cmtat::interfaces::erc1643::{
    IERC1643Dispatcher, IERC1643DispatcherTrait, IERC1643SafeDispatcher,
    IERC1643SafeDispatcherTrait,
};
use cairo_cmtat::roles::DOCUMENT_ROLE;
use openzeppelin::access::accesscontrol::AccessControlComponent;
use openzeppelin::interfaces::accesscontrol::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin_testing::{EventSpyExt, spy_events};
use snforge_std::{start_cheat_block_timestamp_global, start_cheat_caller_address};
use starknet::ContractAddress;
use crate::utils::{ADMIN, HOLDER, OTHER, SUPPLY, assert_reverted_with};

const PROSPECTUS: felt252 = 'prospectus';
const TERMS: felt252 = 'terms';
const REPORT: felt252 = 'report';

fn setup() -> ContractAddress {
    let mut calldata = array![];
    calldata.append_serde(18_u8);
    calldata.append_serde(SUPPLY);
    calldata.append_serde(HOLDER);
    calldata.append_serde(ADMIN);
    let token = openzeppelin_testing::declare_and_deploy("CommonMock", calldata);
    start_cheat_caller_address(token, ADMIN);
    IAccessControlDispatcher { contract_address: token }.grant_role(DOCUMENT_ROLE, OTHER);
    start_cheat_caller_address(token, OTHER);
    token
}

fn docs(token: ContractAddress) -> IERC1643Dispatcher {
    IERC1643Dispatcher { contract_address: token }
}

fn safe_docs(token: ContractAddress) -> IERC1643SafeDispatcher {
    IERC1643SafeDispatcher { contract_address: token }
}

/// Sets PROSPECTUS, TERMS and REPORT, in that order.
fn setup_three() -> ContractAddress {
    let token = setup();
    docs(token).set_document(PROSPECTUS, "ipfs://p", 1);
    docs(token).set_document(TERMS, "ipfs://t", 2);
    docs(token).set_document(REPORT, "ipfs://r", 3);
    token
}

//
// set_document
//

#[test]
fn set_document_stores_and_emits() {
    let token = setup();
    start_cheat_block_timestamp_global(1_000);
    let mut spy = spy_events();
    docs(token).set_document(PROSPECTUS, "ipfs://p", 0xabc);
    assert_eq!(docs(token).get_document(PROSPECTUS), ("ipfs://p", 0xabc, 1_000));
    assert_eq!(docs(token).get_all_documents(), array![PROSPECTUS]);
    spy
        .assert_only_event(
            token,
            DocumentsComponent::Event::DocumentUpdated(
                DocumentsComponent::DocumentUpdated {
                    name: PROSPECTUS, uri: "ipfs://p", document_hash: 0xabc,
                },
            ),
        );
}

#[test]
fn set_document_updates_existing_without_duplicating_name() {
    let token = setup();
    start_cheat_block_timestamp_global(1_000);
    docs(token).set_document(PROSPECTUS, "ipfs://v1", 1);
    start_cheat_block_timestamp_global(2_000);
    docs(token).set_document(PROSPECTUS, "ipfs://v2", 2);
    assert_eq!(docs(token).get_document(PROSPECTUS), ("ipfs://v2", 2, 2_000));
    assert_eq!(docs(token).get_all_documents(), array![PROSPECTUS]);
}

#[test]
fn unknown_document_is_empty() {
    let token = setup();
    assert_eq!(docs(token).get_document(PROSPECTUS), ("", 0, 0));
    assert_eq!(docs(token).get_all_documents(), array![]);
}

#[test]
#[feature("safe_dispatcher")]
fn set_document_rejects_zero_name() {
    let token = setup();
    assert_reverted_with(
        safe_docs(token).set_document(0, "ipfs://p", 1),
        array![errors::ERC1643_INVALID_NAME].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn set_document_requires_document_role() {
    let token = setup();
    start_cheat_caller_address(token, HOLDER);
    assert_reverted_with(
        safe_docs(token).set_document(PROSPECTUS, "ipfs://p", 1),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

//
// remove_document
//

#[test]
fn remove_last_document_emits_with_previous_values() {
    let token = setup_three();
    let mut spy = spy_events();
    docs(token).remove_document(REPORT);
    assert_eq!(docs(token).get_all_documents(), array![PROSPECTUS, TERMS]);
    assert_eq!(docs(token).get_document(REPORT), ("", 0, 0));
    spy
        .assert_only_event(
            token,
            DocumentsComponent::Event::DocumentRemoved(
                DocumentsComponent::DocumentRemoved {
                    name: REPORT, uri: "ipfs://r", document_hash: 3,
                },
            ),
        );
}

/// Removing from the middle moves the last name into the freed slot.
#[test]
fn remove_middle_document_swaps_last_into_place() {
    let token = setup_three();
    docs(token).remove_document(PROSPECTUS);
    assert_eq!(docs(token).get_all_documents(), array![REPORT, TERMS]);
    // The moved name's index is updated: it can still be removed.
    docs(token).remove_document(REPORT);
    assert_eq!(docs(token).get_all_documents(), array![TERMS]);
    assert_eq!(docs(token).get_document(TERMS), ("ipfs://t", 2, 0));
}

#[test]
fn removed_document_can_be_set_again() {
    let token = setup_three();
    docs(token).remove_document(TERMS);
    docs(token).set_document(TERMS, "ipfs://t2", 4);
    assert_eq!(docs(token).get_all_documents(), array![PROSPECTUS, REPORT, TERMS]);
    assert_eq!(docs(token).get_document(TERMS), ("ipfs://t2", 4, 0));
}

#[test]
#[feature("safe_dispatcher")]
fn remove_missing_document_reverts() {
    let token = setup_three();
    docs(token).remove_document(TERMS);
    assert_reverted_with(
        safe_docs(token).remove_document(TERMS), array![errors::ERC1643_MISSING_DOCUMENT].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn remove_document_requires_document_role() {
    let token = setup_three();
    start_cheat_caller_address(token, HOLDER);
    assert_reverted_with(
        safe_docs(token).remove_document(TERMS),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
}

#[test]
fn admin_can_manage_documents() {
    let token = setup();
    start_cheat_caller_address(token, ADMIN);
    docs(token).set_document(PROSPECTUS, "ipfs://p", 1);
    docs(token).remove_document(PROSPECTUS);
    assert_eq!(docs(token).get_all_documents(), array![]);
}

// SPDX-License-Identifier: MPL-2.0
// TokenAttributesComponent (name, symbol, version) and ExtraInformationComponent.

use cairo_cmtat::components::extra_information::ExtraInformationComponent;
use cairo_cmtat::components::token_attributes::TokenAttributesComponent;
use cairo_cmtat::interfaces::erc1643::{Document, DocumentInfo};
use cairo_cmtat::interfaces::extra_information::{
    ICMTATBaseDispatcher, ICMTATBaseDispatcherTrait, ICMTATBaseSafeDispatcher,
    ICMTATBaseSafeDispatcherTrait, Terms,
};
use cairo_cmtat::interfaces::token_attributes::{
    IERC3643ERC20BaseDispatcher, IERC3643ERC20BaseDispatcherTrait, IERC3643ERC20BaseSafeDispatcher,
    IERC3643ERC20BaseSafeDispatcherTrait, IERC3643VersionDispatcher, IERC3643VersionDispatcherTrait,
};
use cairo_cmtat::roles::EXTRA_INFORMATION_ROLE;
use openzeppelin::access::accesscontrol::AccessControlComponent;
use openzeppelin::interfaces::accesscontrol::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::interfaces::erc20::{IERC20MetadataDispatcher, IERC20MetadataDispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin_testing::{EventSpyExt, spy_events};
use snforge_std::{start_cheat_block_timestamp_global, start_cheat_caller_address};
use starknet::ContractAddress;
use crate::utils::{ADMIN, HOLDER, OTHER, SUPPLY, assert_reverted_with};

const DEPLOYED_AT: u64 = 1_000;
const UPDATED_AT: u64 = 2_000;

fn setup() -> ContractAddress {
    start_cheat_block_timestamp_global(DEPLOYED_AT);
    let mut calldata = array![];
    calldata.append_serde(18_u8);
    calldata.append_serde(SUPPLY);
    calldata.append_serde(HOLDER);
    calldata.append_serde(ADMIN);
    let token = openzeppelin_testing::declare_and_deploy("ERC20BaseMock", calldata);
    start_cheat_caller_address(token, ADMIN);
    IAccessControlDispatcher { contract_address: token }.grant_role(EXTRA_INFORMATION_ROLE, OTHER);
    start_cheat_caller_address(token, OTHER);
    token
}

fn base(token: ContractAddress) -> ICMTATBaseDispatcher {
    ICMTATBaseDispatcher { contract_address: token }
}

fn attributes(token: ContractAddress) -> IERC3643ERC20BaseDispatcher {
    IERC3643ERC20BaseDispatcher { contract_address: token }
}

fn missing_role() -> Span<felt252> {
    array![AccessControlComponent::Errors::MISSING_ROLE].span()
}

//
// Token attributes
//

#[test]
fn version_is_cmtat_3_3_0() {
    let token = setup();
    assert_eq!(IERC3643VersionDispatcher { contract_address: token }.version(), "3.3.0");
}

#[test]
fn set_name_updates_metadata_and_emits() {
    let token = setup();
    start_cheat_caller_address(token, ADMIN);
    let mut spy = spy_events();
    attributes(token).set_name("New Name");
    assert_eq!(IERC20MetadataDispatcher { contract_address: token }.name(), "New Name");
    spy
        .assert_only_event(
            token,
            TokenAttributesComponent::Event::Name(
                TokenAttributesComponent::Name { new_name: "New Name" },
            ),
        );
}

#[test]
fn set_symbol_updates_metadata_and_emits() {
    let token = setup();
    start_cheat_caller_address(token, ADMIN);
    let mut spy = spy_events();
    attributes(token).set_symbol("NEW");
    assert_eq!(IERC20MetadataDispatcher { contract_address: token }.symbol(), "NEW");
    spy
        .assert_only_event(
            token,
            TokenAttributesComponent::Event::Symbol(
                TokenAttributesComponent::Symbol { new_symbol: "NEW" },
            ),
        );
}

/// Token attributes require DEFAULT_ADMIN_ROLE, not EXTRA_INFORMATION_ROLE.
#[test]
#[feature("safe_dispatcher")]
fn set_name_and_symbol_require_default_admin() {
    let token = setup();
    let safe = IERC3643ERC20BaseSafeDispatcher { contract_address: token };
    assert_reverted_with(safe.set_name("X"), missing_role());
    assert_reverted_with(safe.set_symbol("X"), missing_role());
}

//
// Extra information
//

#[test]
fn initializer_sets_extra_information() {
    let token = setup();
    assert_eq!(base(token).token_id(), "TOKEN-ID");
    assert_eq!(base(token).information(), "information");
    assert_eq!(
        base(token).terms(),
        Terms {
            name: "Terms",
            doc: Document {
                uri: "https://terms", document_hash: 0x1234, last_modified: DEPLOYED_AT,
            },
        },
    );
}

#[test]
fn set_token_id_emits() {
    let token = setup();
    let mut spy = spy_events();
    base(token).set_token_id("ISIN");
    assert_eq!(base(token).token_id(), "ISIN");
    spy
        .assert_only_event(
            token,
            ExtraInformationComponent::Event::TokenId(
                ExtraInformationComponent::TokenId { new_token_id: "ISIN" },
            ),
        );
}

#[test]
fn set_terms_stamps_block_timestamp_and_emits() {
    let token = setup();
    start_cheat_block_timestamp_global(UPDATED_AT);
    let mut spy = spy_events();
    base(token)
        .set_terms(DocumentInfo { name: "Terms v2", uri: "ipfs://terms", document_hash: 0xabcd });
    let expected = Terms {
        name: "Terms v2",
        doc: Document { uri: "ipfs://terms", document_hash: 0xabcd, last_modified: UPDATED_AT },
    };
    assert_eq!(base(token).terms(), expected.clone());
    spy
        .assert_only_event(
            token,
            ExtraInformationComponent::Event::Terms(
                ExtraInformationComponent::TermsSet { new_term: expected },
            ),
        );
}

#[test]
fn set_information_emits() {
    let token = setup();
    let mut spy = spy_events();
    base(token).set_information("updated");
    assert_eq!(base(token).information(), "updated");
    spy
        .assert_only_event(
            token,
            ExtraInformationComponent::Event::Information(
                ExtraInformationComponent::Information { new_information: "updated" },
            ),
        );
}

#[test]
#[feature("safe_dispatcher")]
fn extra_information_setters_require_role() {
    let token = setup();
    start_cheat_caller_address(token, HOLDER);
    let safe = ICMTATBaseSafeDispatcher { contract_address: token };
    assert_reverted_with(safe.set_token_id("X"), missing_role());
    assert_reverted_with(
        safe.set_terms(DocumentInfo { name: "X", uri: "X", document_hash: 0 }), missing_role(),
    );
    assert_reverted_with(safe.set_information("X"), missing_role());
}

#[test]
fn admin_can_set_extra_information() {
    let token = setup();
    start_cheat_caller_address(token, ADMIN);
    base(token).set_information("by admin");
    assert_eq!(base(token).information(), "by admin");
}

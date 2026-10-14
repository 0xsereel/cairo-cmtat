// SPDX-License-Identifier: MPL-2.0
// AllowlistComponent: management, enforcement on every path, and its place in the
// check order (after active balance, before pause and freeze), on the Allowlist
// preset. With everyone listed the full validation matrix also runs against it.

use cairo_cmtat::components::allowlist::AllowlistComponent;
use cairo_cmtat::errors;
use cairo_cmtat::interfaces::allowlist::{
    IAllowlistModuleDispatcher, IAllowlistModuleDispatcherTrait, IAllowlistModuleSafeDispatcher,
    IAllowlistModuleSafeDispatcherTrait,
};
use cairo_cmtat::interfaces::burn::{
    IBurnFromERC20SafeDispatcher, IBurnFromERC20SafeDispatcherTrait, IERC3643BurnSafeDispatcher,
    IERC3643BurnSafeDispatcherTrait, IForcedBurnERC20SafeDispatcher,
    IForcedBurnERC20SafeDispatcherTrait,
};
use cairo_cmtat::interfaces::debt::{IDebtModuleSafeDispatcher, IDebtModuleSafeDispatcherTrait};
use cairo_cmtat::interfaces::enforcement::{
    IERC3643EnforcementDispatcher, IERC3643EnforcementDispatcherTrait,
};
use cairo_cmtat::interfaces::erc1404::{IERC1404SafeDispatcher, IERC1404SafeDispatcherTrait};
use cairo_cmtat::interfaces::erc20_enforcement::{
    IERC3643ERC20EnforcementDispatcher, IERC3643ERC20EnforcementDispatcherTrait,
    IERC7551ERC20EnforcementDispatcher, IERC7551ERC20EnforcementDispatcherTrait,
    IERC7943FungibleEnforcementDispatcher, IERC7943FungibleEnforcementDispatcherTrait,
};
use cairo_cmtat::interfaces::extra_information::{ICMTATBaseDispatcher, ICMTATBaseDispatcherTrait};
use cairo_cmtat::interfaces::mint::{
    IERC3643MintDispatcher, IERC3643MintDispatcherTrait, IERC3643MintSafeDispatcher,
    IERC3643MintSafeDispatcherTrait,
};
use cairo_cmtat::interfaces::pause::{
    IERC3643PauseDispatcher, IERC3643PauseDispatcherTrait, IERC8343_ID,
};
use cairo_cmtat::interfaces::rule_engine::{
    IValidationRuleEngineSafeDispatcher, IValidationRuleEngineSafeDispatcherTrait,
};
use cairo_cmtat::interfaces::snapshot::{
    ISnapshotEngineModuleSafeDispatcher, ISnapshotEngineModuleSafeDispatcherTrait,
};
use cairo_cmtat::interfaces::validation::{
    IERC3643ComplianceReadDispatcher, IERC3643ComplianceReadDispatcherTrait,
    IERC7551ComplianceDispatcher, IERC7551ComplianceDispatcherTrait,
    IERC7943FungibleSendReceiveCheckDispatcher, IERC7943FungibleSendReceiveCheckDispatcherTrait,
};
use cairo_cmtat::roles::{
    ALLOWLIST_ROLE, BURNER_ROLE, ENFORCER_ROLE, ERC20ENFORCER_ROLE, MINTER_ROLE, PAUSER_ROLE,
};
use openzeppelin::access::accesscontrol::AccessControlComponent;
use openzeppelin::interfaces::accesscontrol::{
    IACCESSCONTROL_ID, IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::interfaces::erc20::{
    IERC20Dispatcher, IERC20DispatcherTrait, IERC20MetadataDispatcher,
    IERC20MetadataDispatcherTrait, IERC20SafeDispatcher, IERC20SafeDispatcherTrait,
};
use openzeppelin::interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait, ISRC5_ID};
use openzeppelin::interfaces::upgrades::{
    IUpgradeableDispatcher, IUpgradeableDispatcherTrait, IUpgradeableSafeDispatcher,
    IUpgradeableSafeDispatcherTrait,
};
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin_testing::{EventSpyExt, spy_events};
use snforge_std::{DeclareResultTrait, declare, get_class_hash, start_cheat_caller_address};
use starknet::ContractAddress;
use crate::utils::{
    ADMIN, BURNER, ENFORCER, ERC20ENFORCER, HOLDER, MINTER, OTHER, PAUSER, RECIPIENT, SPENDER,
    SUPPLY, assert_reverted_with, deploy_allowlist_preset,
};

/// Allowlist manager.
const LISTER: ContractAddress = OTHER;

/// HOLDER is listed; RECIPIENT and SPENDER are not.
fn setup() -> ContractAddress {
    let token = deploy_allowlist_preset();
    start_cheat_caller_address(token, ADMIN);
    let access = IAccessControlDispatcher { contract_address: token };
    access.grant_role(ALLOWLIST_ROLE, LISTER);
    access.grant_role(PAUSER_ROLE, PAUSER);
    access.grant_role(ENFORCER_ROLE, ENFORCER);
    access.grant_role(ERC20ENFORCER_ROLE, ERC20ENFORCER);
    access.grant_role(MINTER_ROLE, MINTER);
    access.grant_role(BURNER_ROLE, BURNER);
    list(token, HOLDER, true);
    start_cheat_caller_address(token, MINTER);
    IERC3643MintDispatcher { contract_address: token }.mint(HOLDER, SUPPLY);
    token
}

fn allowlist(token: ContractAddress) -> IAllowlistModuleDispatcher {
    IAllowlistModuleDispatcher { contract_address: token }
}

fn list(token: ContractAddress, account: ContractAddress, status: bool) {
    start_cheat_caller_address(token, LISTER);
    allowlist(token).set_address_allowlist(account, status);
}

fn as_holder(token: ContractAddress) -> IERC20SafeDispatcher {
    start_cheat_caller_address(token, HOLDER);
    IERC20SafeDispatcher { contract_address: token }
}

fn cannot_send(account: ContractAddress) -> Span<felt252> {
    array![errors::ERC7943_CANNOT_SEND, account.into()].span()
}

fn cannot_receive(account: ContractAddress) -> Span<felt252> {
    array![errors::ERC7943_CANNOT_RECEIVE, account.into()].span()
}

//
// Management
//

#[test]
fn enabled_at_deployment() {
    let token = setup();
    assert!(allowlist(token).is_allowlist_enabled());
    assert!(allowlist(token).is_allowlisted(HOLDER));
    assert!(!allowlist(token).is_allowlisted(RECIPIENT));
}

#[test]
fn set_address_allowlist_emits() {
    let token = setup();
    start_cheat_caller_address(token, LISTER);
    let mut spy = spy_events();
    allowlist(token).set_address_allowlist(RECIPIENT, true);
    assert!(allowlist(token).is_allowlisted(RECIPIENT));
    spy
        .assert_only_event(
            token,
            AllowlistComponent::Event::AddressAddedToAllowlist(
                AllowlistComponent::AddressAddedToAllowlist {
                    account: RECIPIENT, status: true, enforcer: LISTER, data: array![].span(),
                },
            ),
        );
}

#[test]
fn set_address_allowlist_with_data_emits_data() {
    let token = setup();
    start_cheat_caller_address(token, LISTER);
    let data = array!['kyc'].span();
    let mut spy = spy_events();
    allowlist(token).set_address_allowlist_with_data(HOLDER, false, data);
    assert!(!allowlist(token).is_allowlisted(HOLDER));
    spy
        .assert_only_event(
            token,
            AllowlistComponent::Event::AddressAddedToAllowlist(
                AllowlistComponent::AddressAddedToAllowlist {
                    account: HOLDER, status: false, enforcer: LISTER, data,
                },
            ),
        );
}

#[test]
fn batch_set_address_allowlist_sets_each() {
    let token = setup();
    start_cheat_caller_address(token, LISTER);
    allowlist(token)
        .batch_set_address_allowlist(array![HOLDER, RECIPIENT].span(), array![false, true].span());
    assert!(!allowlist(token).is_allowlisted(HOLDER));
    assert!(allowlist(token).is_allowlisted(RECIPIENT));
}

#[test]
#[feature("safe_dispatcher")]
fn batch_set_address_allowlist_validates_input() {
    let token = setup();
    start_cheat_caller_address(token, LISTER);
    let safe = IAllowlistModuleSafeDispatcher { contract_address: token };
    assert_reverted_with(
        safe.batch_set_address_allowlist(array![].span(), array![].span()),
        array![errors::ENF_EMPTY_ACCOUNTS].span(),
    );
    assert_reverted_with(
        safe.batch_set_address_allowlist(array![HOLDER].span(), array![true, false].span()),
        array![errors::ENF_ACCOUNTS_VALUES_LEN_MISMATCH].span(),
    );
}

#[test]
fn enable_allowlist_emits() {
    let token = setup();
    start_cheat_caller_address(token, LISTER);
    let mut spy = spy_events();
    allowlist(token).enable_allowlist(false);
    assert!(!allowlist(token).is_allowlist_enabled());
    spy
        .assert_only_event(
            token,
            AllowlistComponent::Event::AllowlistEnableStatus(
                AllowlistComponent::AllowlistEnableStatus { operator: LISTER, status: false },
            ),
        );
}

#[test]
#[feature("safe_dispatcher")]
fn management_requires_allowlist_role() {
    let token = setup();
    start_cheat_caller_address(token, MINTER);
    let safe = IAllowlistModuleSafeDispatcher { contract_address: token };
    let missing_role = array![AccessControlComponent::Errors::MISSING_ROLE].span();
    assert_reverted_with(safe.set_address_allowlist(RECIPIENT, true), missing_role);
    assert_reverted_with(
        safe.set_address_allowlist_with_data(RECIPIENT, true, array![].span()), missing_role,
    );
    assert_reverted_with(
        safe.batch_set_address_allowlist(array![RECIPIENT].span(), array![true].span()),
        missing_role,
    );
    assert_reverted_with(safe.enable_allowlist(false), missing_role);
}

//
// Enforcement
//

#[test]
#[feature("safe_dispatcher")]
fn transfer_to_unlisted_reverts() {
    let token = setup();
    assert_reverted_with(as_holder(token).transfer(RECIPIENT, 1), cannot_receive(RECIPIENT));
}

#[test]
#[feature("safe_dispatcher")]
fn transfer_from_unlisted_sender_reverts() {
    let token = setup();
    list(token, RECIPIENT, true);
    list(token, HOLDER, false);
    assert_reverted_with(as_holder(token).transfer(RECIPIENT, 1), cannot_send(HOLDER));
}

#[test]
#[feature("safe_dispatcher")]
fn transfer_from_requires_listed_spender() {
    let token = setup();
    list(token, SPENDER, true);
    list(token, RECIPIENT, true);
    start_cheat_caller_address(token, HOLDER);
    IERC20Dispatcher { contract_address: token }.approve(SPENDER, 10);
    list(token, SPENDER, false);
    start_cheat_caller_address(token, SPENDER);
    assert_reverted_with(
        IERC20SafeDispatcher { contract_address: token }.transfer_from(HOLDER, RECIPIENT, 1),
        cannot_send(SPENDER),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn mint_to_unlisted_reverts() {
    let token = setup();
    start_cheat_caller_address(token, MINTER);
    assert_reverted_with(
        IERC3643MintSafeDispatcher { contract_address: token }.mint(RECIPIENT, 1),
        cannot_receive(RECIPIENT),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn burn_from_unlisted_reverts() {
    let token = setup();
    list(token, HOLDER, false);
    start_cheat_caller_address(token, BURNER);
    assert_reverted_with(
        IERC3643BurnSafeDispatcher { contract_address: token }.burn(HOLDER, 1), cannot_send(HOLDER),
    );
}

#[test]
fn disabled_allowlist_allows_unlisted() {
    let token = setup();
    start_cheat_caller_address(token, LISTER);
    allowlist(token).enable_allowlist(false);
    start_cheat_caller_address(token, HOLDER);
    IERC20Dispatcher { contract_address: token }.transfer(RECIPIENT, 1);
    assert_eq!(IERC20Dispatcher { contract_address: token }.balance_of(RECIPIENT), 1);
}

/// Forced transfers bypass every check, the allowlist included.
#[test]
fn forced_transfer_ignores_allowlist() {
    let token = setup();
    start_cheat_caller_address(token, ADMIN);
    IERC7943FungibleEnforcementDispatcher { contract_address: token }
        .forced_transfer(HOLDER, RECIPIENT, 1);
    assert_eq!(IERC20Dispatcher { contract_address: token }.balance_of(RECIPIENT), 1);
}

//
// Check order
//

/// Allowlist runs before freeze: a frozen sender and an unlisted recipient report
/// the recipient.
#[test]
#[feature("safe_dispatcher")]
fn allowlist_is_checked_before_freeze() {
    let token = setup();
    start_cheat_caller_address(token, ENFORCER);
    IERC3643EnforcementDispatcher { contract_address: token }.set_address_frozen(HOLDER, true);
    assert_reverted_with(as_holder(token).transfer(RECIPIENT, 1), cannot_receive(RECIPIENT));
}

#[test]
#[feature("safe_dispatcher")]
fn allowlist_is_checked_before_pause() {
    let token = setup();
    start_cheat_caller_address(token, PAUSER);
    IERC3643PauseDispatcher { contract_address: token }.pause();
    assert_reverted_with(as_holder(token).transfer(RECIPIENT, 1), cannot_receive(RECIPIENT));
}

#[test]
#[feature("safe_dispatcher")]
fn active_balance_is_checked_before_allowlist() {
    let token = setup();
    start_cheat_caller_address(token, ERC20ENFORCER);
    IERC3643ERC20EnforcementDispatcher { contract_address: token }
        .freeze_partial_tokens(HOLDER, SUPPLY);
    let mut expected = array![errors::ERC7943_INSUFFICIENT_UNFROZEN_BAL];
    expected.append_serde(HOLDER);
    expected.append_serde(1_u256);
    expected.append_serde(0_u256);
    assert_reverted_with(as_holder(token).transfer(RECIPIENT, 1), expected.span());
}

//
// Approve and reads
//

#[test]
#[feature("safe_dispatcher")]
fn approve_requires_listed_owner_and_spender() {
    let token = setup();
    assert_reverted_with(as_holder(token).approve(SPENDER, 1), cannot_send(SPENDER));
    list(token, SPENDER, true);
    list(token, HOLDER, false);
    assert_reverted_with(as_holder(token).approve(SPENDER, 1), cannot_send(HOLDER));
    assert!(as_holder(token).approve(SPENDER, 0).unwrap());
}

#[test]
fn can_send_and_receive_require_listing() {
    let token = setup();
    let reads = IERC7943FungibleSendReceiveCheckDispatcher { contract_address: token };
    assert!(reads.can_send(HOLDER));
    assert!(!reads.can_receive(RECIPIENT));
    start_cheat_caller_address(token, ENFORCER);
    IERC3643EnforcementDispatcher { contract_address: token }.set_address_frozen(HOLDER, true);
    assert!(!reads.can_send(HOLDER));
    start_cheat_caller_address(token, LISTER);
    allowlist(token).enable_allowlist(false);
    assert!(reads.can_receive(RECIPIENT));
}

#[test]
fn can_transfer_reflects_allowlist() {
    let token = setup();
    let read = IERC3643ComplianceReadDispatcher { contract_address: token };
    let read_from = IERC7551ComplianceDispatcher { contract_address: token };
    assert!(!read.can_transfer(HOLDER, RECIPIENT, 1));
    list(token, RECIPIENT, true);
    assert!(read.can_transfer(HOLDER, RECIPIENT, 1));
    assert!(!read_from.can_transfer_from(SPENDER, HOLDER, RECIPIENT, 1));
    list(token, SPENDER, true);
    assert!(read_from.can_transfer_from(SPENDER, HOLDER, RECIPIENT, 1));
}

//
// Preset surface
//

fn entrypoint_not_found() -> Array<felt252> {
    array!['ENTRYPOINT_NOT_FOUND', 'ENTRYPOINT_FAILED']
}

#[test]
fn preset_constructor_sets_attributes() {
    let token = deploy_allowlist_preset();
    let metadata = IERC20MetadataDispatcher { contract_address: token };
    assert_eq!(metadata.name(), "Standard Token");
    assert_eq!(metadata.decimals(), 0);
    assert_eq!(ICMTATBaseDispatcher { contract_address: token }.token_id(), "CH0000000000");
    assert!(allowlist(token).is_allowlist_enabled());
    assert_eq!(IERC20Dispatcher { contract_address: token }.total_supply(), 0);
}

#[test]
fn preset_registers_interfaces() {
    let src5 = ISRC5Dispatcher { contract_address: deploy_allowlist_preset() };
    assert!(src5.supports_interface(ISRC5_ID));
    assert!(src5.supports_interface(IACCESSCONTROL_ID));
    assert!(src5.supports_interface(IERC8343_ID));
}

#[test]
#[feature("safe_dispatcher")]
fn preset_upgrade_requires_default_admin() {
    let token = deploy_allowlist_preset();
    let new_class = *declare("ERC20Mock").unwrap().contract_class().class_hash;
    start_cheat_caller_address(token, OTHER);
    assert_reverted_with(
        IUpgradeableSafeDispatcher { contract_address: token }.upgrade(new_class),
        array![AccessControlComponent::Errors::MISSING_ROLE].span(),
    );
    start_cheat_caller_address(token, ADMIN);
    IUpgradeableDispatcher { contract_address: token }.upgrade(new_class);
    assert_eq!(get_class_hash(token), new_class);
}

#[test]
fn preset_has_erc7551_enforcement() {
    let token = setup();
    start_cheat_caller_address(token, ERC20ENFORCER);
    IERC7551ERC20EnforcementDispatcher { contract_address: token }
        .freeze_partial_tokens_with_data(HOLDER, 100, array!['order'].span());
    assert_eq!(
        IERC7551ERC20EnforcementDispatcher { contract_address: token }
            .get_active_balance_of(HOLDER),
        SUPPLY - 100,
    );
}

#[test]
#[feature("safe_dispatcher")]
fn preset_has_no_rule_engine_erc1404_burn_from_or_forced_burn() {
    let token = setup();
    start_cheat_caller_address(token, ADMIN);
    assert_eq!(
        IValidationRuleEngineSafeDispatcher { contract_address: token }.rule_engine().unwrap_err(),
        entrypoint_not_found(),
    );
    assert_eq!(
        IERC1404SafeDispatcher { contract_address: token }
            .detect_transfer_restriction(HOLDER, RECIPIENT, 1)
            .unwrap_err(),
        entrypoint_not_found(),
    );
    assert_eq!(
        IBurnFromERC20SafeDispatcher { contract_address: token }.burn_from(HOLDER, 1).unwrap_err(),
        entrypoint_not_found(),
    );
    assert_eq!(
        IForcedBurnERC20SafeDispatcher { contract_address: token }
            .forced_burn(HOLDER, 1, array![].span())
            .unwrap_err(),
        entrypoint_not_found(),
    );
    assert_eq!(
        IDebtModuleSafeDispatcher { contract_address: token }.credit_events().unwrap_err(),
        entrypoint_not_found(),
    );
    assert_eq!(
        ISnapshotEngineModuleSafeDispatcher { contract_address: token }
            .snapshot_engine()
            .unwrap_err(),
        entrypoint_not_found(),
    );
}

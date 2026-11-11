// SPDX-License-Identifier: MPL-2.0
// Event encoding on each deployed preset. Component suites check every event
// field by field on mocks; here each preset runs one call per event-emitting
// component and the full ordered list of keys and data it emits is compared with
// the expected component events. This catches a component event that is not
// `#[flat]` in the preset (extra key), a missing component, or a changed order.

use cairo_cmtat::components::allowlist::AllowlistComponent;
use cairo_cmtat::components::burn::BurnComponent;
use cairo_cmtat::components::debt::DebtComponent;
use cairo_cmtat::components::documents::DocumentsComponent;
use cairo_cmtat::components::enforcement::EnforcementComponent;
use cairo_cmtat::components::erc20_base::ERC20BaseComponent;
use cairo_cmtat::components::erc20_enforcement::ERC20EnforcementComponent;
use cairo_cmtat::components::extra_information::ExtraInformationComponent;
use cairo_cmtat::components::forced_burn::ForcedBurnComponent;
use cairo_cmtat::components::mint::MintComponent;
use cairo_cmtat::components::pause::PauseComponent;
use cairo_cmtat::components::rule_engine::RuleEngineComponent;
use cairo_cmtat::components::snapshot::SnapshotComponent;
use cairo_cmtat::components::token_attributes::TokenAttributesComponent;
use cairo_cmtat::components::upgrade::UpgradeComponent;
use cairo_cmtat::interfaces::allowlist::{
    IAllowlistModuleDispatcher, IAllowlistModuleDispatcherTrait,
};
use cairo_cmtat::interfaces::burn::{
    IERC3643BurnDispatcher, IERC3643BurnDispatcherTrait, IForcedBurnERC20Dispatcher,
    IForcedBurnERC20DispatcherTrait,
};
use cairo_cmtat::interfaces::debt::{
    CreditEvents, IDebtModuleDispatcher, IDebtModuleDispatcherTrait,
};
use cairo_cmtat::interfaces::enforcement::{
    IERC3643EnforcementDispatcher, IERC3643EnforcementDispatcherTrait,
};
use cairo_cmtat::interfaces::erc1643::{IERC1643Dispatcher, IERC1643DispatcherTrait};
use cairo_cmtat::interfaces::erc20_enforcement::{
    IERC3643ERC20EnforcementDispatcher, IERC3643ERC20EnforcementDispatcherTrait,
    IERC7943FungibleEnforcementDispatcher, IERC7943FungibleEnforcementDispatcherTrait,
};
use cairo_cmtat::interfaces::extra_information::{ICMTATBaseDispatcher, ICMTATBaseDispatcherTrait};
use cairo_cmtat::interfaces::mint::{IERC3643MintDispatcher, IERC3643MintDispatcherTrait};
use cairo_cmtat::interfaces::pause::{IERC3643PauseDispatcher, IERC3643PauseDispatcherTrait};
use cairo_cmtat::interfaces::rule_engine::{
    IValidationRuleEngineDispatcher, IValidationRuleEngineDispatcherTrait,
};
use cairo_cmtat::interfaces::snapshot::{
    ISnapshotEngineModuleDispatcher, ISnapshotEngineModuleDispatcherTrait,
};
use cairo_cmtat::interfaces::token_attributes::{
    IERC3643ERC20BaseDispatcher, IERC3643ERC20BaseDispatcherTrait,
};
use cairo_cmtat::roles::{DEFAULT_ADMIN_ROLE, MINTER_ROLE};
use openzeppelin::access::accesscontrol::AccessControlComponent;
use openzeppelin::interfaces::accesscontrol::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::interfaces::upgrades::{IUpgradeableDispatcher, IUpgradeableDispatcherTrait};
use openzeppelin::token::erc20::ERC20Component;
use openzeppelin::upgrades::UpgradeableComponent;
use snforge_std::{
    Event, EventSpy, EventSpyTrait, EventsFilterTrait, get_class_hash, spy_events,
    start_cheat_caller_address, test_address,
};
use starknet::ContractAddress;
use crate::utils::{
    ADMIN, HOLDER, MINTER, OTHER, RECIPIENT, SPENDER, ZERO, deploy_allowlist_preset,
    deploy_debt_preset, deploy_light_preset, deploy_snapshot_preset, deploy_standard,
};

/// Appends the keys and data `event` would emit as a flat component event.
fn push<T, +starknet::Event<T>, +Drop<T>>(ref expected: Array<Event>, event: T) {
    let mut keys = array![];
    let mut data = array![];
    event.append_keys_and_data(ref keys, ref data);
    expected.append(Event { keys, data });
}

fn emitted(ref spy: EventSpy, token: ContractAddress) -> Array<Event> {
    let mut events = array![];
    for (_, event) in spy.get_events().emitted_by(token).events {
        events.append(event);
    }
    events
}

fn transfer(from: ContractAddress, to: ContractAddress, value: u256) -> ERC20Component::Event {
    ERC20Component::Event::Transfer(ERC20Component::Transfer { from, to, value })
}

fn empty() -> Span<felt252> {
    array![].span()
}

/// Calls shared by every preset (ADMIN holds every role): role grant, mint,
/// burn, approve + transfer_from, pause, address freeze, rename. HOLDER ends with
/// 85 tokens.
fn run_core(token: ContractAddress, ref expected: Array<Event>) {
    start_cheat_caller_address(token, ADMIN);
    IAccessControlDispatcher { contract_address: token }.grant_role(MINTER_ROLE, MINTER);
    push(
        ref expected,
        AccessControlComponent::Event::RoleGranted(
            AccessControlComponent::RoleGranted {
                role: MINTER_ROLE, account: MINTER, sender: ADMIN,
            },
        ),
    );

    IERC3643MintDispatcher { contract_address: token }.mint(HOLDER, 100);
    push(ref expected, transfer(ZERO, HOLDER, 100));
    push(
        ref expected,
        MintComponent::Event::Mint(
            MintComponent::Mint { minter: ADMIN, account: HOLDER, value: 100, data: empty() },
        ),
    );

    IERC3643BurnDispatcher { contract_address: token }.burn(HOLDER, 10);
    push(ref expected, transfer(HOLDER, ZERO, 10));
    push(
        ref expected,
        BurnComponent::Event::Burn(
            BurnComponent::Burn { burner: ADMIN, account: HOLDER, value: 10, data: empty() },
        ),
    );

    start_cheat_caller_address(token, HOLDER);
    IERC20Dispatcher { contract_address: token }.approve(SPENDER, 20);
    push(
        ref expected,
        ERC20Component::Event::Approval(
            ERC20Component::Approval { owner: HOLDER, spender: SPENDER, value: 20 },
        ),
    );
    start_cheat_caller_address(token, SPENDER);
    IERC20Dispatcher { contract_address: token }.transfer_from(HOLDER, RECIPIENT, 5);
    push(ref expected, transfer(HOLDER, RECIPIENT, 5));
    push(
        ref expected,
        ERC20BaseComponent::Event::Spend(
            ERC20BaseComponent::Spend { account: HOLDER, spender: SPENDER, value: 5 },
        ),
    );

    start_cheat_caller_address(token, ADMIN);
    let pause = IERC3643PauseDispatcher { contract_address: token };
    pause.pause();
    push(ref expected, PauseComponent::Event::Paused(PauseComponent::Paused { account: ADMIN }));
    pause.unpause();
    push(
        ref expected, PauseComponent::Event::Unpaused(PauseComponent::Unpaused { account: ADMIN }),
    );

    IERC3643EnforcementDispatcher { contract_address: token }.set_address_frozen(OTHER, true);
    push(
        ref expected,
        EnforcementComponent::Event::AddressFrozen(
            EnforcementComponent::AddressFrozen {
                account: OTHER, is_frozen: true, enforcer: ADMIN, data: empty(),
            },
        ),
    );

    IERC3643ERC20BaseDispatcher { contract_address: token }.set_name("Renamed");
    push(
        ref expected,
        TokenAttributesComponent::Event::Name(
            TokenAttributesComponent::Name { new_name: "Renamed" },
        ),
    );
}

/// Calls shared by the non-Light presets: partial freeze, forced transfer
/// (unfreezing the shortfall), extra information and documents.
fn run_common(token: ContractAddress, ref expected: Array<Event>) {
    start_cheat_caller_address(token, ADMIN);
    IERC3643ERC20EnforcementDispatcher { contract_address: token }
        .freeze_partial_tokens(HOLDER, 30);
    push(
        ref expected,
        ERC20EnforcementComponent::Event::Frozen(
            ERC20EnforcementComponent::Frozen { account: HOLDER, amount: 30 },
        ),
    );
    push(
        ref expected,
        ERC20EnforcementComponent::Event::TokensFrozen(
            ERC20EnforcementComponent::TokensFrozen { account: HOLDER, value: 30, data: empty() },
        ),
    );

    // 85 held, 30 frozen: moving 70 unfreezes 15.
    IERC7943FungibleEnforcementDispatcher { contract_address: token }
        .forced_transfer(HOLDER, RECIPIENT, 70);
    push(
        ref expected,
        ERC20EnforcementComponent::Event::Frozen(
            ERC20EnforcementComponent::Frozen { account: HOLDER, amount: 15 },
        ),
    );
    push(
        ref expected,
        ERC20EnforcementComponent::Event::TokensUnfrozen(
            ERC20EnforcementComponent::TokensUnfrozen { account: HOLDER, value: 15, data: empty() },
        ),
    );
    push(ref expected, transfer(HOLDER, RECIPIENT, 70));
    push(
        ref expected,
        ERC20EnforcementComponent::Event::ForcedTransfer(
            ERC20EnforcementComponent::ForcedTransfer {
                operator: ADMIN, from: HOLDER, to: RECIPIENT, value: 70, data: empty(),
            },
        ),
    );

    ICMTATBaseDispatcher { contract_address: token }.set_information("v2");
    push(
        ref expected,
        ExtraInformationComponent::Event::Information(
            ExtraInformationComponent::Information { new_information: "v2" },
        ),
    );

    IERC1643Dispatcher { contract_address: token }.set_document('doc', "ipfs://d", 1);
    push(
        ref expected,
        DocumentsComponent::Event::DocumentUpdated(
            DocumentsComponent::DocumentUpdated { name: 'doc', uri: "ipfs://d", document_hash: 1 },
        ),
    );
}

fn run_rule_engine(token: ContractAddress, ref expected: Array<Event>) {
    let engine = openzeppelin_testing::declare_and_deploy("RuleEngineRecorder", array![]);
    start_cheat_caller_address(token, ADMIN);
    IValidationRuleEngineDispatcher { contract_address: token }.set_rule_engine(engine);
    push(
        ref expected,
        RuleEngineComponent::Event::RuleEngine(
            RuleEngineComponent::RuleEngineSet { new_rule_engine: engine },
        ),
    );
}

fn run_snapshot_engine(token: ContractAddress, ref expected: Array<Event>) {
    let engine = openzeppelin_testing::declare_and_deploy("SnapshotEngineRecorder", array![]);
    start_cheat_caller_address(token, ADMIN);
    ISnapshotEngineModuleDispatcher { contract_address: token }.set_snapshot_engine(engine);
    push(
        ref expected,
        SnapshotComponent::Event::SnapshotEngine(
            SnapshotComponent::SnapshotEngineSet { new_snapshot_engine: engine },
        ),
    );
}

/// Upgrading to the same class emits OpenZeppelin's `Upgraded`.
fn run_upgrade(token: ContractAddress, ref expected: Array<Event>) {
    start_cheat_caller_address(token, ADMIN);
    let class_hash = get_class_hash(token);
    IUpgradeableDispatcher { contract_address: token }.upgrade(class_hash);
    push(
        ref expected,
        UpgradeableComponent::Event::Upgraded(UpgradeableComponent::Upgraded { class_hash }),
    );
}

/// The constructor first grants DEFAULT_ADMIN_ROLE (sender: the deployer) and
/// records storage version 1; later constructor events depend on the preset.
fn assert_constructor_events(ref spy: EventSpy, token: ContractAddress) {
    let events = emitted(ref spy, token);
    let mut expected = array![];
    push(
        ref expected,
        AccessControlComponent::Event::RoleGranted(
            AccessControlComponent::RoleGranted {
                role: DEFAULT_ADMIN_ROLE, account: ADMIN, sender: test_address(),
            },
        ),
    );
    push(
        ref expected,
        UpgradeComponent::Event::Initialized(UpgradeComponent::Initialized { version: 1 }),
    );
    assert!(events.len() >= 2);
    assert_eq!(*events.at(0), *expected.at(0));
    assert_eq!(*events.at(1), *expected.at(1));
}

#[test]
fn light_events() {
    let mut spy = spy_events();
    let token = deploy_light_preset();
    assert_constructor_events(ref spy, token);

    let mut spy = spy_events();
    let mut expected = array![];
    run_core(token, ref expected);
    // Light burns frozen holdings with forced_burn.
    IERC3643EnforcementDispatcher { contract_address: token }.set_address_frozen(HOLDER, true);
    push(
        ref expected,
        EnforcementComponent::Event::AddressFrozen(
            EnforcementComponent::AddressFrozen {
                account: HOLDER, is_frozen: true, enforcer: ADMIN, data: empty(),
            },
        ),
    );
    let data = array!['court order'].span();
    IForcedBurnERC20Dispatcher { contract_address: token }.forced_burn(HOLDER, 20, data);
    push(ref expected, transfer(HOLDER, ZERO, 20));
    push(
        ref expected,
        ForcedBurnComponent::Event::ForcedTransfer(
            ForcedBurnComponent::ForcedTransfer {
                operator: ADMIN, from: HOLDER, to: ZERO, value: 20, data,
            },
        ),
    );
    run_upgrade(token, ref expected);
    assert_eq!(emitted(ref spy, token), expected);
}

#[test]
fn allowlist_events() {
    let mut spy = spy_events();
    let token = deploy_allowlist_preset();
    assert_constructor_events(ref spy, token);

    let mut spy = spy_events();
    let mut expected = array![];
    start_cheat_caller_address(token, ADMIN);
    let allowlist = IAllowlistModuleDispatcher { contract_address: token };
    for account in array![HOLDER, RECIPIENT, SPENDER] {
        allowlist.set_address_allowlist(account, true);
        push(
            ref expected,
            AllowlistComponent::Event::AddressAddedToAllowlist(
                AllowlistComponent::AddressAddedToAllowlist {
                    account, status: true, enforcer: ADMIN, data: empty(),
                },
            ),
        );
    }
    run_core(token, ref expected);
    run_common(token, ref expected);
    run_upgrade(token, ref expected);
    assert_eq!(emitted(ref spy, token), expected);
}

#[test]
fn standard_events() {
    let mut spy = spy_events();
    let token = deploy_standard(ZERO);
    assert_constructor_events(ref spy, token);

    let mut spy = spy_events();
    let mut expected = array![];
    run_core(token, ref expected);
    run_common(token, ref expected);
    run_rule_engine(token, ref expected);
    run_upgrade(token, ref expected);
    assert_eq!(emitted(ref spy, token), expected);
}

#[test]
fn debt_events() {
    let mut spy = spy_events();
    let token = deploy_debt_preset(ZERO);
    assert_constructor_events(ref spy, token);

    let mut spy = spy_events();
    let mut expected = array![];
    run_core(token, ref expected);
    run_common(token, ref expected);
    let events = CreditEvents { flag_default: false, flag_redeemed: false, rating: "BBB" };
    IDebtModuleDispatcher { contract_address: token }.set_credit_events(events);
    push(
        ref expected,
        DebtComponent::Event::CreditEventsLogEvent(DebtComponent::CreditEventsLogEvent {}),
    );
    run_rule_engine(token, ref expected);
    run_snapshot_engine(token, ref expected);
    run_upgrade(token, ref expected);
    assert_eq!(emitted(ref spy, token), expected);
}

#[test]
fn snapshot_events() {
    let mut spy = spy_events();
    let token = deploy_snapshot_preset(ZERO);
    assert_constructor_events(ref spy, token);

    let mut spy = spy_events();
    let mut expected = array![];
    run_core(token, ref expected);
    run_common(token, ref expected);
    run_rule_engine(token, ref expected);
    run_snapshot_engine(token, ref expected);
    run_upgrade(token, ref expected);
    assert_eq!(emitted(ref spy, token), expected);
}

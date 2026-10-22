// SPDX-License-Identifier: MPL-2.0
// Shared preset suite: every preset is checked against a table of the CMTAT
// variant it ports. Deployment defaults, roles, upgrades and the ABI surface
// (each optional module is present or answers ENTRYPOINT_NOT_FOUND).
// Behaviour lives elsewhere: validation in test_validation_matrix, interface ids
// in test_interface_ids, events in test_preset_events.

use cairo_cmtat::interfaces::allowlist::{
    IAllowlistModuleSafeDispatcher, IAllowlistModuleSafeDispatcherTrait,
};
use cairo_cmtat::interfaces::burn::{
    IBurnFromERC20SafeDispatcher, IBurnFromERC20SafeDispatcherTrait, IERC3643BurnSafeDispatcher,
    IERC3643BurnSafeDispatcherTrait, IForcedBurnERC20SafeDispatcher,
    IForcedBurnERC20SafeDispatcherTrait,
};
use cairo_cmtat::interfaces::debt::{IDebtModuleSafeDispatcher, IDebtModuleSafeDispatcherTrait};
use cairo_cmtat::interfaces::enforcement::{
    IERC3643EnforcementSafeDispatcher, IERC3643EnforcementSafeDispatcherTrait,
};
use cairo_cmtat::interfaces::erc1404::{IERC1404SafeDispatcher, IERC1404SafeDispatcherTrait};
use cairo_cmtat::interfaces::erc1643::{IERC1643SafeDispatcher, IERC1643SafeDispatcherTrait};
use cairo_cmtat::interfaces::erc20_base::{
    IERC20BatchBalanceSafeDispatcher, IERC20BatchBalanceSafeDispatcherTrait,
};
use cairo_cmtat::interfaces::erc20_enforcement::{
    IERC7551ERC20EnforcementSafeDispatcher, IERC7551ERC20EnforcementSafeDispatcherTrait,
    IERC7943FungibleEnforcementSafeDispatcher, IERC7943FungibleEnforcementSafeDispatcherTrait,
};
use cairo_cmtat::interfaces::extra_information::{
    ICMTATBaseSafeDispatcher, ICMTATBaseSafeDispatcherTrait,
};
use cairo_cmtat::interfaces::mint::{IERC3643MintSafeDispatcher, IERC3643MintSafeDispatcherTrait};
use cairo_cmtat::interfaces::pause::{
    IERC3643PauseDispatcher, IERC3643PauseDispatcherTrait, IERC3643PauseSafeDispatcher,
    IERC3643PauseSafeDispatcherTrait, IERC8343Dispatcher, IERC8343DispatcherTrait,
};
use cairo_cmtat::interfaces::rule_engine::{
    IValidationRuleEngineSafeDispatcher, IValidationRuleEngineSafeDispatcherTrait,
};
use cairo_cmtat::interfaces::snapshot::{
    ISnapshotEngineModuleSafeDispatcher, ISnapshotEngineModuleSafeDispatcherTrait,
};
use cairo_cmtat::interfaces::token_attributes::{
    IERC3643ERC20BaseSafeDispatcher, IERC3643ERC20BaseSafeDispatcherTrait,
    IERC3643VersionDispatcher, IERC3643VersionDispatcherTrait,
};
use cairo_cmtat::interfaces::upgrade::{IUpgradeVersionDispatcher, IUpgradeVersionDispatcherTrait};
use cairo_cmtat::roles::{
    ALLOWLIST_ROLE, BURNER_FROM_ROLE, BURNER_ROLE, BURNER_SELF_ROLE, DEBT_ROLE, DEFAULT_ADMIN_ROLE,
    DOCUMENT_ROLE, ENFORCER_ROLE, ERC20ENFORCER_ROLE, EXTRA_INFORMATION_ROLE, MINTER_ROLE,
    PAUSER_ROLE, SNAPSHOOTER_ROLE,
};
use openzeppelin::access::accesscontrol::AccessControlComponent;
use openzeppelin::interfaces::accesscontrol::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::interfaces::erc20::{
    IERC20Dispatcher, IERC20DispatcherTrait, IERC20MetadataDispatcher,
    IERC20MetadataDispatcherTrait,
};
use openzeppelin::interfaces::upgrades::{
    IUpgradeableDispatcher, IUpgradeableDispatcherTrait, IUpgradeableSafeDispatcher,
    IUpgradeableSafeDispatcherTrait,
};
use snforge_std::{DeclareResultTrait, declare, get_class_hash, start_cheat_caller_address};
use starknet::ContractAddress;
use crate::utils::{
    ADMIN, HOLDER, OTHER, RECIPIENT, ZERO, assert_reverted_with, deploy_allowlist_preset,
    deploy_debt_preset, deploy_light_preset, deploy_snapshot_preset, deploy_standard,
};

/// Optional modules, per CMTAT variant.
#[derive(Copy, Drop, Debug, PartialEq)]
struct Features {
    /// ERC-3643 / ERC-7943 partial freeze and forced transfer (not in Core).
    partial_freeze: bool,
    /// ERC-7551 `_with_data` enforcement overloads and `get_active_balance_of`.
    erc7551: bool,
    /// Core-only forced burn of a frozen address.
    forced_burn: bool,
    burn_from: bool,
    extra_information: bool,
    documents: bool,
    rule_engine: bool,
    erc1404: bool,
    allowlist: bool,
    debt: bool,
    snapshot: bool,
}

#[derive(Drop)]
struct Preset {
    name: ByteArray,
    token: ContractAddress,
    features: Features,
}

const NONE: Features = Features {
    partial_freeze: false,
    erc7551: false,
    forced_burn: false,
    burn_from: false,
    extra_information: false,
    documents: false,
    rule_engine: false,
    erc1404: false,
    allowlist: false,
    debt: false,
    snapshot: false,
};

/// Each preset deployed with no engines, and the modules of its CMTAT base.
fn presets() -> Array<Preset> {
    array![
        // CMTATBaseCore
        Preset {
            name: "light",
            token: deploy_light_preset(),
            features: Features { forced_burn: true, ..NONE },
        },
        // CMTATBaseAllowlist
        Preset {
            name: "allowlist",
            token: deploy_allowlist_preset(),
            features: Features {
                partial_freeze: true,
                erc7551: true,
                extra_information: true,
                documents: true,
                allowlist: true,
                ..NONE,
            },
        },
        // CMTATBaseERC7551Enforcement
        Preset {
            name: "standard",
            token: deploy_standard(ZERO),
            features: Features {
                partial_freeze: true,
                erc7551: true,
                burn_from: true,
                extra_information: true,
                documents: true,
                rule_engine: true,
                erc1404: true,
                ..NONE,
            },
        },
        // CMTATBaseDebt
        Preset {
            name: "debt",
            token: deploy_debt_preset(ZERO),
            features: Features {
                partial_freeze: true,
                extra_information: true,
                documents: true,
                rule_engine: true,
                debt: true,
                snapshot: true,
                ..NONE,
            },
        },
        // CMTATBaseERC2771Snapshot
        Preset {
            name: "snapshot",
            token: deploy_snapshot_preset(ZERO),
            features: Features {
                partial_freeze: true,
                burn_from: true,
                extra_information: true,
                documents: true,
                rule_engine: true,
                erc1404: true,
                snapshot: true,
                ..NONE,
            },
        },
    ]
}

/// Whether the entry point exists: it either returned or reverted for a reason
/// other than a missing selector.
fn exists<T, +Drop<T>>(result: Result<T, Array<felt252>>) -> bool {
    match result {
        Result::Ok(_) => true,
        Result::Err(panic_data) => panic_data != array![
            'ENTRYPOINT_NOT_FOUND', 'ENTRYPOINT_FAILED',
        ],
    }
}

/// Probes one entry point of each optional module, as ADMIN.
#[feature("safe_dispatcher")]
fn probe(token: ContractAddress) -> Features {
    start_cheat_caller_address(token, ADMIN);
    let empty = array![].span();
    Features {
        partial_freeze: exists(
            IERC7943FungibleEnforcementSafeDispatcher { contract_address: token }
                .get_frozen_tokens(HOLDER),
        ),
        erc7551: exists(
            IERC7551ERC20EnforcementSafeDispatcher { contract_address: token }
                .get_active_balance_of(HOLDER),
        ),
        forced_burn: exists(
            IForcedBurnERC20SafeDispatcher { contract_address: token }
                .forced_burn(HOLDER, 1, empty),
        ),
        burn_from: exists(
            IBurnFromERC20SafeDispatcher { contract_address: token }.burn_from(HOLDER, 1),
        ),
        extra_information: exists(ICMTATBaseSafeDispatcher { contract_address: token }.token_id()),
        documents: exists(IERC1643SafeDispatcher { contract_address: token }.get_all_documents()),
        rule_engine: exists(
            IValidationRuleEngineSafeDispatcher { contract_address: token }.rule_engine(),
        ),
        erc1404: exists(
            IERC1404SafeDispatcher { contract_address: token }
                .detect_transfer_restriction(HOLDER, RECIPIENT, 1),
        ),
        allowlist: exists(
            IAllowlistModuleSafeDispatcher { contract_address: token }.is_allowlist_enabled(),
        ),
        debt: exists(IDebtModuleSafeDispatcher { contract_address: token }.credit_events()),
        snapshot: exists(
            ISnapshotEngineModuleSafeDispatcher { contract_address: token }.snapshot_engine(),
        ),
    }
}

#[test]
fn optional_modules_match_cmtat_variant() {
    for preset in presets() {
        assert_eq!(probe(preset.token), preset.features, "preset {}", preset.name);
    }
}

/// ERC-20, batch balance, pause / ERC-8343, address freeze, mint, burn, token
/// attributes, version and upgrades are in every variant.
#[test]
#[feature("safe_dispatcher")]
fn core_modules_in_every_preset() {
    for preset in presets() {
        let token = preset.token;
        start_cheat_caller_address(token, ADMIN);
        assert!(
            exists(
                IERC20BatchBalanceSafeDispatcher { contract_address: token }
                    .batch_balance_of(array![HOLDER].span()),
            ),
            "batch_balance_of {}",
            preset.name,
        );
        assert!(
            exists(IERC3643PauseSafeDispatcher { contract_address: token }.paused()),
            "paused {}",
            preset.name,
        );
        assert!(
            exists(IERC3643EnforcementSafeDispatcher { contract_address: token }.is_frozen(HOLDER)),
            "is_frozen {}",
            preset.name,
        );
        assert!(
            exists(IERC3643MintSafeDispatcher { contract_address: token }.mint(HOLDER, 10)),
            "mint {}",
            preset.name,
        );
        assert!(
            exists(IERC3643BurnSafeDispatcher { contract_address: token }.burn(HOLDER, 10)),
            "burn {}",
            preset.name,
        );
        assert!(
            exists(IERC3643ERC20BaseSafeDispatcher { contract_address: token }.set_name("N")),
            "set_name {}",
            preset.name,
        );
    }
}

#[test]
fn deployment_defaults() {
    for preset in presets() {
        let token = preset.token;
        let metadata = IERC20MetadataDispatcher { contract_address: token };
        assert_eq!(metadata.name(), "Standard Token", "{}", preset.name);
        assert_eq!(metadata.symbol(), "STD", "{}", preset.name);
        assert_eq!(metadata.decimals(), 0, "{}", preset.name);
        assert_eq!(IERC20Dispatcher { contract_address: token }.total_supply(), 0);
        assert_eq!(IERC3643VersionDispatcher { contract_address: token }.version(), "3.3.0");
        assert_eq!(
            IUpgradeVersionDispatcher { contract_address: token }.initialized_version(),
            1,
            "{}",
            preset.name,
        );
        assert!(!IERC3643PauseDispatcher { contract_address: token }.paused(), "{}", preset.name);
        assert!(!IERC8343Dispatcher { contract_address: token }.deactivated(), "{}", preset.name);
    }
}

/// The admin holds every role (CMTAT `hasRole` override); nobody else holds
/// any role at deployment.
#[test]
fn admin_holds_every_role() {
    let roles = array![
        DEFAULT_ADMIN_ROLE, PAUSER_ROLE, ENFORCER_ROLE, ERC20ENFORCER_ROLE, MINTER_ROLE,
        BURNER_ROLE, BURNER_FROM_ROLE, BURNER_SELF_ROLE, EXTRA_INFORMATION_ROLE, DOCUMENT_ROLE,
        SNAPSHOOTER_ROLE, ALLOWLIST_ROLE, DEBT_ROLE,
    ];
    for preset in presets() {
        let access = IAccessControlDispatcher { contract_address: preset.token };
        for role in roles.span() {
            assert!(access.has_role(*role, ADMIN), "{} admin {}", preset.name, *role);
            assert!(!access.has_role(*role, OTHER), "{} other {}", preset.name, *role);
        }
    }
}

/// Core role-gated calls reject an account without the role.
#[test]
#[feature("safe_dispatcher")]
fn core_calls_require_roles() {
    let missing_role = array![AccessControlComponent::Errors::MISSING_ROLE].span();
    for preset in presets() {
        let token = preset.token;
        start_cheat_caller_address(token, OTHER);
        assert_reverted_with(
            IERC3643MintSafeDispatcher { contract_address: token }.mint(HOLDER, 1), missing_role,
        );
        assert_reverted_with(
            IERC3643BurnSafeDispatcher { contract_address: token }.burn(HOLDER, 1), missing_role,
        );
        assert_reverted_with(
            IERC3643PauseSafeDispatcher { contract_address: token }.pause(), missing_role,
        );
        assert_reverted_with(
            IERC3643EnforcementSafeDispatcher { contract_address: token }
                .set_address_frozen(HOLDER, true),
            missing_role,
        );
        assert_reverted_with(
            IERC3643ERC20BaseSafeDispatcher { contract_address: token }.set_name("N"), missing_role,
        );
    }
}

/// `upgrade` requires DEFAULT_ADMIN_ROLE; the admin can replace the class.
#[test]
#[feature("safe_dispatcher")]
fn upgrade_requires_default_admin() {
    let new_class = *declare("ERC20Mock").unwrap().contract_class().class_hash;
    for preset in presets() {
        let token = preset.token;
        start_cheat_caller_address(token, OTHER);
        assert_reverted_with(
            IUpgradeableSafeDispatcher { contract_address: token }.upgrade(new_class),
            array![AccessControlComponent::Errors::MISSING_ROLE].span(),
        );
        start_cheat_caller_address(token, ADMIN);
        IUpgradeableDispatcher { contract_address: token }.upgrade(new_class);
        assert_eq!(get_class_hash(token), new_class, "{}", preset.name);
    }
}

// SPDX-License-Identifier: MPL-2.0

pub mod errors;
pub mod roles;

// CMTAT modules as Starknet components
pub mod components {
    pub mod access;
    pub mod allowlist;
    pub mod burn;
    pub mod debt;
    pub mod documents;
    pub mod enforcement;
    pub mod erc1404;
    pub mod erc20_base;
    pub mod erc20_enforcement;
    pub mod extra_information;
    pub mod forced_burn;
    pub mod hooks;
    pub mod mint;
    pub mod pause;
    pub mod rule_engine;
    pub mod snapshot;
    pub mod token_attributes;
    pub mod upgrade;
    pub mod validation;
}

// CMTAT interfaces
pub mod interfaces {
    pub mod allowlist;
    pub mod burn;
    pub mod constructor;
    pub mod debt;
    pub mod enforcement;
    pub mod erc1404;
    pub mod erc1643;
    pub mod erc20_base;
    pub mod erc20_enforcement;
    pub mod extra_information;
    pub mod icmtat;
    pub mod mint;
    pub mod pause;
    pub mod rule_engine;
    pub mod snapshot;
    pub mod token_attributes;
    pub mod validation;
}

// Deployable tokens composed from the components
pub mod presets {
    pub mod allowlist;
    pub mod light;
    pub mod standard;
}

// Legacy contracts, removed as each preset lands
pub mod contracts {
    pub mod debt_cmtat;
}

// Test doubles and sample engines; production engines live in separate repositories
pub mod mocks {
    pub mod access_control_mock;
    pub mod common_mock;
    pub mod enforcement_mock;
    pub mod erc20_enforcement_mock;
    pub mod erc20_mock;
    pub mod forced_burn_mock;
    pub mod pause_mock;
    pub mod rule_engine;
    pub mod rule_engine_recorder;
    pub mod snapshot_engine;
    pub mod snapshot_engine_recorder;
}

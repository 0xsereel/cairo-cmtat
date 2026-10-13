// SPDX-License-Identifier: MPL-2.0

pub mod errors;
pub mod roles;

// CMTAT modules as Starknet components
pub mod components {
    pub mod access;
    pub mod burn;
    pub mod enforcement;
    pub mod erc20_base;
    pub mod erc20_enforcement;
    pub mod forced_burn;
    pub mod hooks;
    pub mod mint;
    pub mod pause;
    pub mod validation;
}

// CMTAT interfaces
pub mod interfaces {
    pub mod burn;
    pub mod enforcement;
    pub mod erc20_base;
    pub mod erc20_enforcement;
    pub mod icmtat;
    pub mod mint;
    pub mod pause;
}

// CMTAT contract implementations - Production ready contracts
pub mod contracts {
    pub mod allowlist_cmtat;
    pub mod debt_cmtat;
    pub mod light_cmtat;
    pub mod standard_cmtat;
}

// Test doubles and sample engines; production engines live in separate repositories
pub mod mocks {
    pub mod access_control_mock;
    pub mod enforcement_mock;
    pub mod erc20_base_mock;
    pub mod erc20_enforcement_mock;
    pub mod erc20_mock;
    pub mod forced_burn_mock;
    pub mod pause_mock;
    pub mod rule_engine;
    pub mod snapshot_engine;
}

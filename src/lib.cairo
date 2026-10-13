// SPDX-License-Identifier: MPL-2.0

pub mod errors;
pub mod roles;

// CMTAT interfaces
pub mod interfaces {
    pub mod icmtat;
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
    pub mod rule_engine;
    pub mod snapshot_engine;
}

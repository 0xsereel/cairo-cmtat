// SPDX-License-Identifier: MPL-2.0

// CMTAT interfaces
pub mod interfaces {
    pub mod icmtat;
}

// CMTAT contract implementations - Production ready contracts
pub mod contracts {
    pub mod standard_cmtat;
    pub mod light_cmtat;
    pub mod debt_cmtat;
}

// CMTAT engines - Rule and Snapshot engines
pub mod engines {
    pub mod rule_engine;
    pub mod snapshot_engine;
}

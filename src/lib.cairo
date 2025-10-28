// SPDX-License-Identifier: MPL-2.0
// Cairo CMTAT Implementation Library

// Working CMTAT implementation
pub mod working_cmtat;

// CMTAT interfaces
pub mod interfaces {
    pub mod icmtat;
}

// CMTAT contract implementations - All working and deployable
pub mod contracts {
    pub mod standard_cmtat;
    pub mod light_cmtat;
    pub mod debt_cmtat;
    pub mod snapshot_demo;
}

// CMTAT engines - Rule and Snapshot engines
pub mod engines {
    pub mod rule_engine;
    pub mod snapshot_engine;
}

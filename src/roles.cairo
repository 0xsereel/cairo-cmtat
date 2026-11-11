// SPDX-License-Identifier: MPL-2.0
// CMTAT v3.3.0 role identifiers.
//
// Ids follow the OpenZeppelin Cairo convention: `selector!("<NAME>")`
// (sn_keccak of the role name), not Solidity's `keccak256("<NAME>")`.
// DEFAULT_ADMIN_ROLE is OpenZeppelin's zero role and implicitly holds every role.

pub use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;

// Core
pub const PAUSER_ROLE: felt252 = selector!("PAUSER_ROLE");
pub const ENFORCER_ROLE: felt252 = selector!("ENFORCER_ROLE");
pub const ERC20ENFORCER_ROLE: felt252 = selector!("ERC20ENFORCER_ROLE");
pub const MINTER_ROLE: felt252 = selector!("MINTER_ROLE");
pub const BURNER_ROLE: felt252 = selector!("BURNER_ROLE");
pub const BURNER_FROM_ROLE: felt252 = selector!("BURNER_FROM_ROLE");
pub const BURNER_SELF_ROLE: felt252 = selector!("BURNER_SELF_ROLE");

// Extensions
pub const EXTRA_INFORMATION_ROLE: felt252 = selector!("EXTRA_INFORMATION_ROLE");
pub const DOCUMENT_ROLE: felt252 = selector!("DOCUMENT_ROLE");
pub const SNAPSHOOTER_ROLE: felt252 = selector!("SNAPSHOOTER_ROLE");

// Options
pub const ALLOWLIST_ROLE: felt252 = selector!("ALLOWLIST_ROLE");
pub const DEBT_ROLE: felt252 = selector!("DEBT_ROLE");

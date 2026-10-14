// SPDX-License-Identifier: MPL-2.0
// Shared test helpers. Generic addresses, deployment and event-queue helpers come
// from openzeppelin_testing; this module adds CMTAT role holders and revert checks.

use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin_testing::AsAddressTrait;

pub use openzeppelin_testing::constants::{ADMIN, OTHER, RECIPIENT, SPENDER, SUPPLY, ZERO};
use openzeppelin_testing::constants::{NAME, OWNER, SYMBOL};
use starknet::ContractAddress;

// Role holders
pub const PAUSER: ContractAddress = 'PAUSER'.as_address();
pub const ENFORCER: ContractAddress = 'ENFORCER'.as_address();
pub const ERC20ENFORCER: ContractAddress = 'ERC20ENFORCER'.as_address();
pub const MINTER: ContractAddress = 'MINTER'.as_address();
pub const BURNER: ContractAddress = 'BURNER'.as_address();

// Token holders
pub const HOLDER: ContractAddress = OWNER;

/// Deploys `ERC20Mock` with `SUPPLY` minted to `HOLDER` and `ADMIN` as default admin.
pub fn deploy_erc20_mock() -> ContractAddress {
    let mut calldata = array![];
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(SUPPLY);
    calldata.append_serde(HOLDER);
    calldata.append_serde(ADMIN);
    openzeppelin_testing::declare_and_deploy("ERC20Mock", calldata)
}

/// Asserts that a safe-dispatcher call reverted with exactly `expected` as the
/// contract's panic data. The `'ENTRYPOINT_FAILED'` felt appended by the call is
/// accounted for. Use for tables of cases in one test; prefer `#[should_panic]`
/// for single cases.
pub fn assert_reverted_with<T, +Drop<T>>(
    result: Result<T, Array<felt252>>, expected: Span<felt252>,
) {
    let mut full = array![];
    full.append_span(expected);
    full.append('ENTRYPOINT_FAILED');
    match result {
        Result::Ok(_) => panic!("Expected revert, call succeeded"),
        Result::Err(panic_data) => assert_eq!(panic_data, full),
    }
}

/// Deploys `CMTATStandard` with `ADMIN` as default admin and `rule_engine` (may be
/// zero). Mints nothing.
pub fn deploy_standard(rule_engine: ContractAddress) -> ContractAddress {
    let mut calldata = array![];
    calldata.append_serde(ADMIN);
    calldata.append_serde(standard_erc20_attributes());
    calldata.append_serde(standard_extra_information());
    calldata.append_serde(rule_engine);
    openzeppelin_testing::declare_and_deploy("CMTATStandard", calldata)
}

pub fn standard_erc20_attributes() -> cairo_cmtat::interfaces::constructor::ERC20Attributes {
    cairo_cmtat::interfaces::constructor::ERC20Attributes {
        name: "Standard Token", symbol: "STD", decimals: 0,
    }
}

pub fn standard_extra_information() -> cairo_cmtat::interfaces::constructor::ExtraInformationAttributes {
    cairo_cmtat::interfaces::constructor::ExtraInformationAttributes {
        token_id: "CH0000000000",
        terms: cairo_cmtat::interfaces::erc1643::DocumentInfo {
            name: "Terms", uri: "ipfs://terms", document_hash: 0xabcd,
        },
        information: "Standard CMTAT",
    }
}

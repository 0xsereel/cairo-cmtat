# CMTAT implementation for Starknet (Cairo)

> This project has not undergone an audit and is provided as-is without any warranties.

[CMTAT](https://cmta.ch/standards/cmta-token-cmtat) is a framework for the tokenization of securities and other financial instruments in compliance with local regulations. This project implements a CMTAT version in Cairo allowing financial institutions to adopt the standard on Starknet.

This implementation is based on the [Solidity version](https://github.com/CMTA/CMTAT).

## Features

- **CMTAT framework implementation**
- **Four Module Variants** - Light, Allowlist, Debt, and Standard implementations
-  **ERC20 Compliance** with regulatory extensions
- **Role-Based Access Control** with role getter functions
- **Batch Operations** for efficient multi-address operations
- **Transfer Validation** (ERC-1404 compatible)
- **OpenZeppelin Components** for security and reliability

## Quick Start

### Prerequisites
Install `scarb`, a toolchain and package manager for Cairo and Starknet ecosystems. 

See [docs.swmansion.com/scarb/](https://docs.swmansion.com/scarb/)

### Build & Test
```bash
# Build all contracts
scarb build

# Run tests
scarb test
```

### Deploy
```bash
# Deploy complete ecosystem
./scripts/deploy.sh
```

## Module Overview

### Light CMTAT
**Minimal feature set for basic CMTAT compliance**

**Constructor:**
```cairo
constructor(
    admin: ContractAddress,
    name: ByteArray,
    symbol: ByteArray,
    initial_supply: u256,
    recipient: ContractAddress
)
```

**Features:**
- Basic ERC20 functionality
- Minting (mint, batch_mint)
- Burning (burn, burn_from, batch_burn, forced_burn, burn_and_mint)
- Pause/Unpause/Deactivate
- Address freezing (set_address_frozen, batch_set_address_frozen)
- Information management (terms, information, token_id)
- Batch balance queries
- 4 Role constants (DEFAULT_ADMIN, MINTER, PAUSER, ENFORCER)

**Use Cases:** Standard token deployments, simple compliance requirements

---

### Allowlist CMTAT
**All Light features plus allowlist functionality**

**Constructor:**
```cairo
constructor(
    admin: ContractAddress,
    name: ByteArray,
    symbol: ByteArray,
    initial_supply: u256,
    recipient: ContractAddress
)
```

**Additional Features:**
- Allowlist control (enable_allowlist, set_address_allowlist, batch_set_address_allowlist)
-  Partial token freezing (freeze_partial_tokens, unfreeze_partial_tokens)
- Active balance queries (get_active_balance_of)
- Engine management (snapshot_engine, document_engine)
- 9 Role constants (includes ERC20ENFORCER, SNAPSHOOTER, DOCUMENT, EXTRA_INFORMATION)

**Use Cases:** Regulated tokens with whitelist requirements, KYC/AML compliance

---

### Debt CMTAT
**Specialized for debt securities**

**Constructor:**
```cairo
constructor(
    admin: ContractAddress,
    name: ByteArray,
    symbol: ByteArray,
    initial_supply: u256,
    recipient: ContractAddress
)
```

**Debt-Specific Features:**
- Debt information management (debt, set_debt)
- Credit events tracking (credit_events, set_credit_events)
- Debt engine integration (debt_engine, set_debt_engine)
- Default flagging (flag_default)
- All Allowlist features (except allowlist-specific)
- 10 Role constants (includes DEBT_ROLE)

**Use Cases:** Corporate bonds, structured debt products, fixed income securities

---

### Standard CMTAT
**Full feature set with transfer validation**

**Constructor:**
```cairo
constructor(
    admin: ContractAddress,
    name: ByteArray,
    symbol: ByteArray,
    initial_supply: u256,
    recipient: ContractAddress
)
```

**Advanced Features:**
- Transfer validation (restriction_code, message_for_transfer_restriction)
- ERC-1404 compliance
-  All core CMTAT features
- 9 Role constants

**Use Cases:** Advanced compliance, institutional securities with transfer validation

---

## ABI Compatibility

Here is the list of implemented functions.

### Common Functions (All Modules)

**Information Management:**
```cairo
fn terms(self: @ContractState) -> ByteArray
fn set_terms(ref self: ContractState, new_terms: ByteArray) -> bool
fn information(self: @ContractState) -> ByteArray
fn set_information(ref self: ContractState, new_information: ByteArray) -> bool
fn token_id(self: @ContractState) -> ByteArray
fn set_token_id(ref self: ContractState, new_token_id: ByteArray) -> bool
```

**Batch Operations:**
```cairo
fn batch_balance_of(self: @ContractState, accounts: Span<ContractAddress>) -> Array<u256>
fn batch_mint(ref self: ContractState, tos: Span<ContractAddress>, values: Span<u256>) -> bool
fn batch_burn(ref self: ContractState, accounts: Span<ContractAddress>, values: Span<u256>) -> bool
```

**Role Getters:**
```cairo
fn get_default_admin_role(self: @ContractState) -> felt252
fn get_minter_role(self: @ContractState) -> felt252
fn get_pauser_role(self: @ContractState) -> felt252
// ... all role getters
```

**Minting & Burning:**
```cairo
fn mint(ref self: ContractState, to: ContractAddress, value: u256) -> bool
fn burn(ref self: ContractState, value: u256) -> bool
fn burn_from(ref self: ContractState, from: ContractAddress, value: u256) -> bool
fn burn_and_mint(ref self: ContractState, from: ContractAddress, to: ContractAddress, value: u256) -> bool
```

**Pause & Freeze:**
```cairo
fn paused(self: @ContractState) -> bool
fn pause(ref self: ContractState) -> bool
fn unpause(ref self: ContractState) -> bool
fn deactivated(self: @ContractState) -> bool
fn deactivate_contract(ref self: ContractState) -> bool
fn set_address_frozen(ref self: ContractState, account: ContractAddress, is_frozen: bool) -> bool
fn batch_set_address_frozen(ref self: ContractState, accounts: Span<ContractAddress>, frozen: Span<bool>) -> bool
fn is_frozen(self: @ContractState, account: ContractAddress) -> bool
```

### Module-Specific Functions

**Allowlist Module:**
```cairo
fn enable_allowlist(ref self: ContractState, status: bool) -> bool
fn is_allowlist_enabled(self: @ContractState) -> bool
fn set_address_allowlist(ref self: ContractState, account: ContractAddress, status: bool) -> bool
fn batch_set_address_allowlist(ref self: ContractState, accounts: Span<ContractAddress>, statuses: Span<bool>) -> bool
fn is_allowlisted(self: @ContractState, account: ContractAddress) -> bool
```

**Debt Module:**
```cairo
fn debt(self: @ContractState) -> ByteArray
fn set_debt(ref self: ContractState, debt_: ByteArray) -> bool
fn credit_events(self: @ContractState) -> ByteArray
fn set_credit_events(ref self: ContractState, credit_events_: ByteArray) -> bool
fn debt_engine(self: @ContractState) -> ContractAddress
fn set_debt_engine(ref self: ContractState, debt_engine_: ContractAddress) -> bool
fn flag_default(ref self: ContractState) -> bool
```

**Standard Module:**
```cairo
fn restriction_code(self: @ContractState, from: ContractAddress, to: ContractAddress, value: u256) -> StandardCMTAT::RESTRICTION_CODE
fn message_for_transfer_restriction(self: @ContractState, restriction_code: StandardCMTAT::RESTRICTION_CODE) -> ByteArray
```

> **Note:** The `restriction_code` and `message_for_transfer_restriction` function signatures now use `StandardCMTAT::RESTRICTION_CODE` instead of `u8` for improved type safety. Callers must regenerate ABI/dispatcher after this signature change.

---

## Interface Introspection (SRC5)

Each preset registers the same interfaces through SRC5 (`supports_interface`) that its CMTAT v3.3.0 base reports through ERC-165 (`supportsInterface`).

### Interface ids

An id is the XOR of the SNIP-5 extended selectors of its functions. Each selector is `sn_keccak` of the function's signature string, built with these rules:

- Type names are short: `ContractAddress`, `felt252`, `u8`, `u64`.
- A struct is written as the tuple of its fields:
  - `u256` → `(u128,u128)`
  - `ByteArray` → `(Array<bytes31>,felt252,u32)`
  - `Span<T>` → `(@Array<T>)`
- An enum is written as `E(...)`, so `bool` → `E((),())`.
- The output follows `->`, and is omitted when the function returns nothing. The `self` parameter is not included.

The ids use the Cairo function names. Where a Cairo name differs from CMTAT's, the CMTAT overload is in brackets, e.g. `mint_with_data` (`mint(account, value, data)`). CMTAT's ERC-165 id covers the same functions.

| Constant | Value | CMTAT ERC-165 id | Extended signatures |
|---|---|---|---|
| `ISRC5_ID` (OpenZeppelin) | `0x3f918d17e5ee77373b56385708f855659a07f75997f365cf87748628532a055` | `0x01ffc9a7` | `supports_interface(felt252)->E((),())` |
| `IACCESSCONTROL_ID` (OpenZeppelin) | `0x23700be02858dbe2ac4dc9c9f66d0b6b0ed81ec7f970ca6844500a56ff61751` | `0x7965db0b` | OpenZeppelin AccessControl |
| `IERC8343_ID` | `0xb0170a1ae08515ecaede32d780ec7e7d7dc84266f5e007cf6411db91ff8b` | `0xe9cd80b0` | `deactivate_contract()`<br>`deactivated()->E((),())` |
| `IERC5679_ID` | `0x33c89e5cd6ccac5fc9f984d94defdfc99b2cadda15b0422f41b9b848de233c8` | `0xd0017968` | `mint_with_data(ContractAddress,(u128,u128),(@Array<felt252>))` (`mint(account, value, data)`)<br>`burn_with_data(ContractAddress,(u128,u128),(@Array<felt252>))` (`burn(account, value, data)`) |
| `IERC7943_ID` | `0x14e4423410d8cc56f38ff233c6d8d427700f0c7929a1ef8c0c9d117955b3ec1` | `0x3edbb4c4` | `get_frozen_tokens(ContractAddress)->(u128,u128)`<br>`set_frozen_tokens(ContractAddress,(u128,u128))->E((),())`<br>`forced_transfer(ContractAddress,ContractAddress,(u128,u128))->E((),())`<br>`can_send(ContractAddress)->E((),())`<br>`can_receive(ContractAddress)->E((),())`<br>`can_transfer(ContractAddress,ContractAddress,(u128,u128))->E((),())` |
| `IERC1643_ID` | `0x1a10ec61334b275b2f19413a43f011e7465e9f29c94a34b07b7d33c2bb93d50` | `0xecfecec8` | `get_document(felt252)->((Array<bytes31>,felt252,u32),(u128,u128),u64)`<br>`get_all_documents()->Array<felt252>`<br>`set_document(felt252,(Array<bytes31>,felt252,u32),(u128,u128))`<br>`remove_document(felt252)` |
| `IERC1404_ID` | `0x3a3c667090ad0aa8f47799a4995ee74f3ca62bdaf5d64d75cd41596255f182a` | — | `detect_transfer_restriction(ContractAddress,ContractAddress,(u128,u128))->u8`<br>`message_for_transfer_restriction(u8)->(Array<bytes31>,felt252,u32)` |
| `IERC1404_EXTEND_ID` | `0xff711fc962f6084c61e8a81115059929cf17dc2fe08b83e577453465d0e7fe` | `0x78a8de7d` | the two ERC-1404 functions, plus<br>`detect_transfer_restriction_from(ContractAddress,ContractAddress,ContractAddress,(u128,u128))->u8` |

Notes:
- `IERC1404_EXTEND_ID` includes the ERC-1404 functions, as CMTAT's `ERC1404EXTEND_INTERFACE_ID` does.
- The ERC-1404 and ERC-1643 ids depend on the `ByteArray` encoding above. CMTAT has no Cairo id to check it against.
- `tests/test_interface_ids.cairo` recomputes every id defined in this crate from its signature strings. The ERC-8343 id is recomputed in `tests/test_pause.cairo`.

### Interfaces per preset

| Interface | Light | Allowlist | Debt | Standard | Snapshot |
|---|:-:|:-:|:-:|:-:|:-:|
| SRC5 | ✓ | ✓ | ✓ | ✓ | ✓ |
| AccessControl | ✓ | ✓ | ✓ | ✓ | ✓ |
| ERC-8343 | ✓ | ✓ | ✓ | ✓ | ✓ |
| ERC-5679 | ✓ | ✓ | ✓ | ✓ | ✓ |
| ERC-7943 | | ✓ | ✓ | ✓ | ✓ |
| ERC-1643 | | ✓ | ✓ | ✓ | ✓ |
| ERC-1404 | | | | ✓ | ✓ |
| IERC1404Extend | | | | ✓ | ✓ |

Each column matches the preset's CMTAT base:
- **Light** follows `CMTATBaseCore`. It has no partial freeze, so it doesn't report ERC-7943.
- **Allowlist** and **Debt** follow `CMTATBaseAccessControl`. CMTAT's Debt base sits below `CMTATBaseERC1404`, so Debt doesn't report ERC-1404.
- **Standard** and **Snapshot** follow `CMTATBaseERC1404`.

---

## Feature Comparison Matrix

| Feature | Light | Allowlist | Debt | Standard |
|---------|-------|-----------|------|----------|
| **Basic ERC20** | ✅ | ✅ | ✅ | ✅ |
| **Minting** | ✅ | ✅ | ✅ | ✅ |
| **Burning** | ✅ | ✅ | ✅ | ✅ |
| **Forced Burn** | ✅ | ❌ | ❌ | ❌ |
| **Pause/Unpause** | ✅ | ✅ | ✅ | ✅ |
| **Deactivation** | ✅ | ✅ | ✅ | ✅ |
| **Address Freezing** | ✅ | ✅ | ✅ | ✅ |
| **Partial Token Freezing** | ❌ | ✅ | ✅ | ✅ |
| **Batch Operations** | ✅ | ✅ | ✅ | ✅ |
| **Information Management** | ✅ | ✅ | ✅ | ✅ |
| **Allowlist** | ❌ | ✅ | ❌ | ❌ |
| **Debt Management** | ❌ | ❌ | ✅ | ❌ |
| **Transfer Validation** | ❌ | ❌ | ❌ | ✅ |
| **Engine Integration** | ❌ | ✅ | ✅ | ✅ |
| **Role Count** | 4 | 9 | 10 | 9 |

---

## Architecture

```
cairo-cmtat/
├── src/
│   ├── contracts/
│   │   ├── light_cmtat.cairo       # Minimal CMTAT (4 roles)
│   │   ├── allowlist_cmtat.cairo   # With allowlist (9 roles)
│   │   ├── debt_cmtat.cairo        # For debt securities (10 roles)
│   │   └── standard_cmtat.cairo    # Full feature set (10 roles)
│   ├── engines/
│   │   ├── rule_engine.cairo       # Transfer restrictions
│   │   └── snapshot_engine.cairo   # Balance snapshots
│   └── interfaces/
│       └── icmtat.cairo            # Interface definitions
├── tests/
│   └── cmtat_tests.cairo           # Comprehensive tests
└── scripts/
    └── deploy.sh                    # Deployment automation
```

---

## Use Cases & Examples

### Regulatory Compliant Token
```cairo
// Deploy Allowlist CMTAT for KYC/AML compliance
let allowlist_cmtat = deploy_allowlist_cmtat(
    admin,
    "Regulated Security Token",
    "RST",
    1000000 * 10^18,
    treasury
);

// Enable allowlist
allowlist_cmtat.enable_allowlist(true);

// Add approved addresses
let kyc_addresses = array![addr1, addr2, addr3];
let statuses = array![true, true, true];
allowlist_cmtat.batch_set_address_allowlist(kyc_addresses, statuses);
```

### Corporate Bond Token
```cairo
// Deploy Debt CMTAT for bond issuance
let bond_token = deploy_debt_cmtat(
    admin,
    "Corporate Bond 2025",
    "BOND25",
    10000000 * 10^18,
    issuer
);

// Set debt information
bond_token.set_debt("5% Senior Notes due 2025");
bond_token.set_credit_events("Investment Grade BBB+");

// Integrate debt calculation engine
bond_token.set_debt_engine(debt_calculation_engine);
```

---

## Security Features

### Role-Based Access Control
- **DEFAULT_ADMIN_ROLE**: Master administrator, can grant/revoke all roles
- **MINTER_ROLE**: Can create new tokens
- **BURNER_ROLE**: Can destroy tokens
- **PAUSER_ROLE**: Can pause/unpause contract
- **ENFORCER_ROLE**: Can freeze/unfreeze addresses
- **ERC20ENFORCER_ROLE**: Can freeze partial tokens
- **SNAPSHOOTER_ROLE**: Can create snapshots
- **DOCUMENT_ROLE**: Can manage documents
- **EXTRA_INFORMATION_ROLE**: Can update token metadata
- **DEBT_ROLE**: Can manage debt parameters

### Transfer Restrictions
All modules implement transfer restrictions via ERC20 hooks:
- Pause state check
- Sender/recipient freeze check
- Active balance validation (for partial freezing)
- Custom validation (via transfer validation in Standard)

---

## Deployment Guide

### Step 1: Build Contracts
```bash
scarb build
```

### Step 2: Configure Environment
```bash
cp .env.example .env
# Edit .env with your configuration
```

### Step 3: Deploy
```bash
./scripts/deploy.sh
```

The script will:
1. Deploy all four CMTAT modules
2. Set up proper role assignments
3. Configure engine integrations
4. Output all contract addresses

---

## Testing

```bash
# Run all tests
scarb test

# Run specific test
scarb test test_name

# Run with verbose output
scarb test --verbose
```

---

## Documentation

### Technical Specifications
- [CMTAT Whitepaper](https://www.cmtat.org/)
- [Cairo Documentation](https://book.cairo-lang.org/)
- [Starknet Documentation](https://docs.starknet.io/)

### API Reference
Full API documentation for all modules available in-code documentation.

---

## Development

### Prerequisites
- Cairo 2.13.1
- Scarb 2.13.1
- Sierra: 1.7.0
- OpenZeppelin Cairo [v2.0.0](https://github.com/OpenZeppelin/cairo-contracts/releases/tag/v2.0.0)

### Project Structure
```
src/contracts/     # Token implementations
src/engines/       # Compliance engines
src/interfaces/    # Contract interfaces
tests/            # Test suite
scripts/          # Deployment scripts
```

---

## Contributing

Contributions are welcome! Please follow these guidelines:
1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

---

## License

Mozilla Public License 2.0 (MPL-2.0)

---

## Links

- **Starknet**: [https://starknet.io](https://starknet.io)
- **CMTAT**: [https://www.cmtat.org](https://www.cmtat.org)
- **OpenZeppelin Cairo**: [https://github.com/OpenZeppelin/cairo-contracts](https://github.com/OpenZeppelin/cairo-contracts)

---

**Built for compliant securities on Starknet**

*Version 0.1.0 - ABI Compatible Implementation*

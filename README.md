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
- **Cross-Chain Support** (Standard module)
- **Transfer Validation** (ERC-1404 compatible)
- **Meta-Transaction Support** (Allowlist & Standard modules)
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
    forwarder_irrevocable: ContractAddress,  // For meta-transactions
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
- Meta-transaction support (is_trusted_forwarder)
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
**Full feature set with cross-chain support**

**Constructor:**
```cairo
constructor(
    forwarder_irrevocable: ContractAddress,  // For meta-transactions
    admin: ContractAddress,
    name: ByteArray,
    symbol: ByteArray,
    initial_supply: u256,
    recipient: ContractAddress
)
```

**Advanced Features:**
- Cross-chain operations (crosschain_mint, crosschain_burn)
- Transfer validation (restriction_code, message_for_transfer_restriction)
- ERC-1404 compliance
-  All core CMTAT features
- 10 Role constants (includes CROSS_CHAIN_ROLE)

**Use Cases:** Multi-chain deployments, advanced compliance, institutional securities

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
fn crosschain_mint(ref self: ContractState, to: ContractAddress, value: u256) -> bool
fn crosschain_burn(ref self: ContractState, from: ContractAddress, value: u256) -> bool
fn restriction_code(self: @ContractState, from: ContractAddress, to: ContractAddress, value: u256) -> u8
fn message_for_transfer_restriction(self: @ContractState, restriction_code: u8) -> ByteArray
```

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
| **Cross-Chain** | ❌ | ❌ | ❌ | ✅ |
| **Transfer Validation** | ❌ | ❌ | ❌ | ✅ |
| **Meta-Transactions** | ❌ | ✅ | ❌ | ✅ |
| **Engine Integration** | ❌ | ✅ | ✅ | ✅ |
| **Role Count** | 4 | 9 | 10 | 10 |

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
    forwarder,
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

### Multi-Chain Security Token
```cairo
// Deploy Standard CMTAT with cross-chain support
let standard_cmtat = deploy_standard_cmtat(
    forwarder,
    admin,
    "Global Security Token",
    "GST",
    5000000 * 10^18,
    treasury
);

// Enable cross-chain operations
standard_cmtat.grant_role(CROSS_CHAIN_ROLE, bridge_operator);

// Bridge tokens to another chain
standard_cmtat.crosschain_burn(user, 1000 * 10^18);
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
- **CROSS_CHAIN_ROLE**: Can execute cross-chain operations

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

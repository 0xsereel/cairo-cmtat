# Cairo CMTAT - CMTAT Token Implementation for Starknet

A comprehensive implementation of CMTAT (Capital Markets and Technology Association Token) standard in Cairo for Starknet, based on the [CMTAT v3.0.0 Solidity reference implementation](https://github.com/CMTA/CMTAT).

## Overview

This project implements the CMTAT token standard in Cairo, providing:
- ✅ **ERC20 Compliance**: Full ERC20 token functionality
- ✅ **Access Control**: Role-based permissions (Admin, Minter, Burner, Enforcer)
- ✅ **Compliance Features**: Address freezing and partial token freezing
- ✅ **ERC-1404 Support**: Transfer restriction detection and messaging
- ✅ **Metadata Management**: Terms and flags for regulatory compliance
- ✅ **OpenZeppelin Components**: Built on battle-tested OpenZeppelin Cairo contracts

## Features

### Core CMTAT Functionality

1. **Role-Based Access Control**
   - `DEFAULT_ADMIN_ROLE`: Full administrative control
   - `MINTER_ROLE`: Mint new tokens
   - `BURNER_ROLE`: Burn tokens
   - `ENFORCER_ROLE`: Freeze addresses and tokens

2. **Enforcement Mechanisms**
   - **Address Freezing**: Completely freeze an address from transfers
   - **Partial Token Freezing**: Freeze specific token amounts while allowing partial transfers
   - **Active Balance Tracking**: Distinguish between total and available balances

3. **Compliance & Metadata**
   - **Terms**: Store regulatory terms as felt252
   - **Flag**: Additional metadata flag
   - **ERC-1404 Integration**: Transfer restriction codes and messages

### Technical Stack

- **Cairo**: v2.6.3+
- **Scarb**: v2.6.4+
- **OpenZeppelin Cairo Contracts**: v0.13.0
- **Starknet Foundry**: v0.25.0 (for testing)

## Project Structure

```
cairo-cmtat/
├── src/
│   ├── lib.cairo                    # Library entry point
│   ├── working_cmtat.cairo          # Main CMTAT implementation
│   ├── interfaces/
│   │   ├── icmtat.cairo            # CMTAT interface definitions
│   │   └── engines.cairo           # Engine interfaces (Document, Debt)
│   ├── modules/                    # Modular components (future)
│   └── contracts/                  # Specialized implementations (future)
├── scripts/
│   └── deploy_cmtat.sh             # Deployment script
├── tests/
│   ├── mod.cairo
│   └── cmtat_tests.cairo
├── Scarb.toml                      # Project configuration
└── README.md
```

## Installation

### Prerequisites

1. **Install Scarb** (Cairo package manager)
```bash
curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh
```

2. **Install Starkli** (Starknet CLI)
```bash
curl https://get.starkli.sh | sh
starkliup
```

### Build the Project

```bash
# Clone the repository
git clone <repository-url>
cd cairo-cmtat

# Build the project
scarb build
```

## Usage

### Deploying a CMTAT Token

The project includes a comprehensive deployment script that handles the entire deployment process:

```bash
# Basic deployment to Sepolia testnet
./scripts/deploy_cmtat.sh \
  --network sepolia \
  --name "My Security Token" \
  --symbol "MST"

# Advanced deployment with custom parameters
./scripts/deploy_cmtat.sh \
  --network sepolia \
  --account my_account \
  --admin 0x123... \
  --recipient 0x456... \
  --supply 10000000 \
  --name "Company Shares" \
  --symbol "CSHARE" \
  --terms 0x54657374 \
  --flag 0x1
```

#### Deployment Options

| Option | Description | Default |
|--------|-------------|---------|
| `--network` | Starknet network (sepolia/mainnet) | sepolia |
| `--account` | Account name for deployment | default |
| `--admin` | Admin address | 0x123...def |
| `--recipient` | Initial token recipient | 0x123...def |
| `--supply` | Initial supply (with decimals) | 1000000000000000000000000 |
| `--name` | Token name | CMTAT Token |
| `--symbol` | Token symbol | CMTAT |
| `--terms` | Terms felt252 | 0x54657374546f6b656e |
| `--flag` | Flag felt252 | 0x1 |

### Interacting with the Contract

#### Read Functions

```bash
# Check token balance
starkli call <CONTRACT_ADDRESS> balance_of <ACCOUNT> --network sepolia

# Get total supply
starkli call <CONTRACT_ADDRESS> total_supply --network sepolia

# Check if address is frozen
starkli call <CONTRACT_ADDRESS> is_frozen <ACCOUNT> --network sepolia

# Get frozen token amount for an address
starkli call <CONTRACT_ADDRESS> get_frozen_tokens <ACCOUNT> --network sepolia

# Get active (unfrozen) balance
starkli call <CONTRACT_ADDRESS> active_balance_of <ACCOUNT> --network sepolia

# Get terms
starkli call <CONTRACT_ADDRESS> terms --network sepolia

# Get flag
starkli call <CONTRACT_ADDRESS> flag --network sepolia

# Check transfer restrictions
starkli call <CONTRACT_ADDRESS> detect_transfer_restriction <FROM> <TO> <AMOUNT> --network sepolia
```

#### Write Functions

```bash
# Mint tokens (requires MINTER_ROLE)
starkli invoke <CONTRACT_ADDRESS> mint <RECIPIENT> <AMOUNT> \
  --network sepolia --account <ACCOUNT>

# Burn tokens (requires BURNER_ROLE)
starkli invoke <CONTRACT_ADDRESS> burn <FROM> <AMOUNT> \
  --network sepolia --account <ACCOUNT>

# Transfer tokens
starkli invoke <CONTRACT_ADDRESS> transfer <TO> <AMOUNT> \
  --network sepolia --account <ACCOUNT>

# Freeze an address (requires ENFORCER_ROLE)
starkli invoke <CONTRACT_ADDRESS> freeze_address <ACCOUNT> \
  --network sepolia --account <ACCOUNT>

# Unfreeze an address (requires ENFORCER_ROLE)
starkli invoke <CONTRACT_ADDRESS> unfreeze_address <ACCOUNT> \
  --network sepolia --account <ACCOUNT>

# Freeze partial tokens (requires ENFORCER_ROLE)
starkli invoke <CONTRACT_ADDRESS> freeze_tokens <ACCOUNT> <AMOUNT> \
  --network sepolia --account <ACCOUNT>

# Unfreeze partial tokens (requires ENFORCER_ROLE)
starkli invoke <CONTRACT_ADDRESS> unfreeze_tokens <ACCOUNT> <AMOUNT> \
  --network sepolia --account <ACCOUNT>

# Set terms (requires DEFAULT_ADMIN_ROLE)
starkli invoke <CONTRACT_ADDRESS> set_terms <NEW_TERMS> \
  --network sepolia --account <ACCOUNT>

# Set flag (requires DEFAULT_ADMIN_ROLE)
starkli invoke <CONTRACT_ADDRESS> set_flag <NEW_FLAG> \
  --network sepolia --account <ACCOUNT>
```

#### Role Management

```bash
# Grant a role (requires DEFAULT_ADMIN_ROLE)
starkli invoke <CONTRACT_ADDRESS> grant_role <ROLE> <ACCOUNT> \
  --network sepolia --account <ACCOUNT>

# Revoke a role (requires DEFAULT_ADMIN_ROLE)
starkli invoke <CONTRACT_ADDRESS> revoke_role <ROLE> <ACCOUNT> \
  --network sepolia --account <ACCOUNT>

# Check if account has a role
starkli call <CONTRACT_ADDRESS> has_role <ROLE> <ACCOUNT> --network sepolia

# Role identifiers
# MINTER_ROLE: 'MINTER' (felt252)
# BURNER_ROLE: 'BURNER' (felt252)
# ENFORCER_ROLE: 'ENFORCER' (felt252)
```

## Smart Contract Architecture

### WorkingCMTAT Contract

The main implementation (`src/working_cmtat.cairo`) uses OpenZeppelin components:

```cairo
component!(path: ERC20Component, storage: erc20, event: ERC20Event);
component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);
component!(path: SRC5Component, storage: src5, event: SRC5Event);
```

### Key Components

1. **ERC20Component**: Standard token functionality
2. **AccessControlComponent**: Role-based permissions
3. **SRC5Component**: Interface detection

### Storage Layout

```cairo
struct Storage {
    erc20: ERC20Component::Storage,
    access_control: AccessControlComponent::Storage,
    src5: SRC5Component::Storage,
    terms: felt252,
    flag: felt252,
    frozen_addresses: LegacyMap<ContractAddress, bool>,
    frozen_tokens: LegacyMap<ContractAddress, u256>,
}
```

## Testing

```bash
# Run tests with Starknet Foundry
snforge test

# Run specific test
snforge test test_mint

# Run with verbose output
snforge test -vv
```

## Deployment Info

All deployments are automatically logged to the `deployments/` directory with detailed information:

```json
{
  "network": "sepolia",
  "contract_address": "0x...",
  "class_hash": "0x...",
  "admin": "0x...",
  "recipient": "0x...",
  "initial_supply": "1000000",
  "token_name": "My Token",
  "token_symbol": "MTK",
  "terms": "0x...",
  "flag": "0x...",
  "timestamp": "2025-01-27T10:00:00Z"
}
```

## ERC-1404 Compliance

The contract implements ERC-1404 restricted token transfer standard:

### Restriction Codes

| Code | Meaning |
|------|---------|
| 0 | No restriction |
| 1 | Insufficient active balance |
| 2 | Sender frozen |
| 3 | Recipient frozen |

### Usage

```cairo
let code = detect_transfer_restriction(from, to, amount);
let message = message_for_transfer_restriction(code);
```

## Security Considerations

1. **Role Management**: Carefully manage role assignments
2. **Admin Key Security**: Protect the admin private key
3. **Freeze Powers**: Use enforcement powers responsibly
4. **Audit**: Consider professional security audit before mainnet deployment

## CMTAT Engines

This project includes Rule and Snapshot engines for extended functionality:

### Rule Engine
- **Purpose**: Control transfer restrictions (ERC-1404 compliant)
- **Features**: Address whitelisting, max balance limits, custom restriction logic
- **Use Cases**: KYC/AML compliance, accredited investor restrictions

### Snapshot Engine  
- **Purpose**: Record historical token balances
- **Features**: Point-in-time balance queries, batch operations
- **Use Cases**: Dividend distributions, voting rights, compliance reporting

See [ENGINES.md](./ENGINES.md) for detailed deployment and usage instructions.

### Quick Start with Engines

```bash
# 1. Deploy CMTAT Token
./scripts/deploy_cmtat.sh --type standard --name "My Token" --symbol "MTK"

# 2. Deploy Rule Engine for transfer restrictions
./scripts/deploy_engines.sh --engine rule --token-address 0x... --owner 0x...

# 3. Deploy Snapshot Engine for historical records
./scripts/deploy_engines.sh --engine snapshot --token-address 0x... --owner 0x...
```

## Project Structure (Updated)

```
cairo-cmtat/
├── src/
│   ├── working_cmtat.cairo        # ✅ Full CMTAT implementation
│   ├── contracts/                  # ✅ Specialized CMTAT variants
│   │   ├── simple_standard_cmtat.cairo    # Standard with pause
│   │   ├── simple_light_cmtat.cairo       # Lightweight version
│   │   └── simple_debt_cmtat.cairo        # For debt instruments
│   ├── engines/                    # ✅ NEW: Engine implementations
│   │   ├── rule_engine.cairo      # Transfer restrictions
│   │   └── snapshot_engine.cairo  # Historical balances
│   └── interfaces/
│       └── icmtat.cairo
├── scripts/
│   ├── deploy_cmtat.sh            # ✅ Deploy CMTAT tokens
│   └── deploy_engines.sh          # ✅ NEW: Deploy engines
├── ENGINES.md                      # ✅ NEW: Engine documentation
└── README.md
```

## Roadmap

- [x] ~~Implement Pausable functionality~~ (Included in StandardCMTAT)
- [x] ~~Add Snapshot support~~ (Snapshot Engine implemented)
- [x] ~~Rule Engine for transfer restrictions~~ (Rule Engine implemented)
- [ ] Implement Document Engine integration
- [ ] Comprehensive test suite
- [ ] Gas optimization
- [ ] Security audit

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

This project is licensed under the Mozilla Public License 2.0 (MPL-2.0).

## References

- [CMTAT Solidity Implementation](https://github.com/CMTA/CMTAT)
- [CMTAT Specification v3.0.0](https://github.com/CMTA/CMTAT/blob/master/CMTATSpecificationV3.0.0.pdf)
- [OpenZeppelin Cairo Contracts](https://github.com/OpenZeppelin/cairo-contracts)
- [Cairo Book](https://book.cairo-lang.org/)
- [Starknet Documentation](https://docs.starknet.io/)

## Support

For questions and support:
- Open an issue on GitHub
- Contact the development team
- Check the Cairo and Starknet community resources

---

**Built with ❤️ for the Starknet ecosystem**

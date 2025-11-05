# Cairo CMTAT - Regulated Securities on Starknet

A comprehensive implementation of CMTAT (Capital Markets and Technology Association Token) standard in Cairo for Starknet, featuring compliance and snapshot engines for regulated securities.

## Features

-  **ERC20 Compliance** with regulatory extensions
-  **Role-Based Access Control** (Admin, Minter, Burner, Debt roles)
-  **Rule Engine** for transfer restrictions and whitelisting
-  **Snapshot Engine** for historical balance tracking
-  **Three Contract Variants**: Standard, Light, and Debt CMTAT
-  **OpenZeppelin Components** for security and reliability

## Quick Start

### Prerequisites
```bash
# Install Scarb (Cairo package manager)
curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh

# Install Starkli (Starknet CLI)
curl https://get.starkli.sh | sh
starkliup
```

### Deploy
```bash
# Build contracts
scarb build

# Deploy complete ecosystem
./scripts/deploy.sh
```

### Test
```bash
# Run contract tests
scarb test
```

## Manual Deployment (if needed)

If the automated deployment script has issues with the Debt CMTAT contract, you can deploy it manually:

### Deploy Debt CMTAT Manually
```bash
# After running ./scripts/deploy.sh and sourcing .env
source .env

# Deploy Debt CMTAT with proper ByteArray encoding
starkli deploy \
  0x073df1d757f9927b737ae61d1b350aeefa4df2bf1cfc73c47c017b9e80e246e7 \
  --account ~/.starkli-wallets/deployer/account.json \
  --keystore ~/.starkli-wallets/deployer/keystore.json \
  --rpc https://starknet-sepolia.public.blastapi.io/rpc/v0.7 \
  $ADMIN_ADDR \
  0 0x4465627420434d544154 11 \
  0 0x44434d544154 7 \
  0 0x56302e302e30 6 \
  18 \
  $ADMIN_ADDR \
  $RULE_ENGINE \
  $SNAPSHOT_ENGINE
```

**Parameters explained:**
- `0x4465627420434d544154 11` = "Debt CMTAT" (ByteArray format)
- `0x44434d544154 7` = "DCMTAT" (symbol)
- `0x56302e302e30 6` = "V0.0.0" (version)
- `18` = decimals
- Uses existing `$RULE_ENGINE` and `$SNAPSHOT_ENGINE` from automated deployment

## Live Deployment (Starknet Sepolia)

All contracts are deployed and ready for interaction:

### Compliance Engines
- **Rule Engine**: [`0x071b9729d9943a931ab7c068ced6c03ee178453bf63552a1c4969e0a7594e382`](https://sepolia.starkscan.co/contract/0x071b9729d9943a931ab7c068ced6c03ee178453bf63552a1c4969e0a7594e382)
- **Snapshot Engine**: [`0x05b864c7eae89e9c740a5f5c24a87c4e194e0fb0381a4ac9152613e43718be83`](https://sepolia.starkscan.co/contract/0x05b864c7eae89e9c740a5f5c24a87c4e194e0fb0381a4ac9152613e43718be83)

### CMTAT Tokens
- **Standard CMTAT**: [`0x02145b0cf916124aa4955dd9b7c73631b5ec6411257d64d56efb8e05e242ecd9`](https://sepolia.starkscan.co/contract/0x02145b0cf916124aa4955dd9b7c73631b5ec6411257d64d56efb8e05e242ecd9)
- **Light CMTAT**: [`0x057de503d9d662b1a212f6ed6279e2f65c722e9ce8e236d0cddc30339f74702e`](https://sepolia.starkscan.co/contract/0x057de503d9d662b1a212f6ed6279e2f65c722e9ce8e236d0cddc30339f74702e)
- **Debt CMTAT**: [`0x00343aabb8312f3827c75130e9af815a9c853a0a60f7acf4772909624bbf5800`](https://sepolia.starkscan.co/contract/0x00343aabb8312f3827c75130e9af815a9c853a0a60f7acf4772909624bbf5800)

## Architecture

### Standard CMTAT
Full-featured implementation with complete ERC20 functionality, compliance features, and engine integration.

### Light CMTAT  
Lightweight version with essential ERC20 and basic compliance features for minimal deployments. Useful for stablecoins.

### Debt CMTAT
Specialized for debt securities with ISIN tracking, maturity dates, and interest rate management.

### Compliance Engines
- **Rule Engine**: Controls transfer restrictions and address whitelisting
- **Snapshot Engine**: Records historical balances for regulatory reporting
- **Modular Design**: Engines can be shared across multiple CMTAT instances

## Contract Structure

```
src/
├── contracts/
│   ├── standard_cmtat.cairo    # Full-featured CMTAT
│   ├── light_cmtat.cairo       # Lightweight version  
│   └── debt_cmtat.cairo        # Debt securities
├── engines/
│   ├── rule_engine.cairo       # Transfer restrictions
│   └── snapshot_engine.cairo   # Balance snapshots
└── interfaces/
    └── icmtat.cairo            # Interface definitions
```

## Usage Example

```cairo
// Interact with deployed contracts
let standard_cmtat = IStandardCMTATDispatcher { contract_address: standard_cmtat_address };
let name = standard_cmtat.name();
let balance = standard_cmtat.balance_of(user_address);

// Use rule engine for compliance
let rule_engine = IRuleEngineDispatcher { contract_address: rule_engine_address };
let restriction_code = rule_engine.detect_transfer_restriction(from, to, amount);

// Create snapshots for reporting
let snapshot_engine = ISnapshotEngineDispatcher { contract_address: snapshot_engine_address };
let snapshot_id = snapshot_engine.schedule_snapshot(timestamp);
```

## Technical Stack

- **Cairo**: v2.6.3+
- **Scarb**: v2.6.4+  
- **OpenZeppelin Cairo**: v0.13.0
- **Starknet**: Sepolia testnet

## License

Mozilla Public License 2.0 (MPL-2.0)

---

**Built for regulated securities on Starknet** 🛡️

## License

Mozilla Public License 2.0 (MPL-2.0)

---

**Built for regulated securities on Starknet** 🛡️

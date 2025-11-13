# CMTAT Factory Contract

The CMTAT Factory is a smart contract that enables the deployment of Standard, Debt, and Light CMTAT token implementations on Starknet. It provides a centralized, upgradeable mechanism for deploying compliant security token contracts.

## Overview

The factory contract follows the factory pattern, storing class hashes of the three CMTAT implementations and providing deployment functions that use the `deploy_syscall` to create new contract instances.

## Features

### 1. **Multi-Implementation Support**
- Deploy Standard CMTAT (full-featured implementation)
- Deploy Debt CMTAT (specialized for debt instruments)
- Deploy Light CMTAT (core compliance features)

### 2. **Class Hash Management**
- Store and update class hashes for each implementation
- Only owner can update class hashes
- Emits events on class hash updates

### 3. **Deployment Tracking**
- Tracks all deployed contracts
- Query deployment count
- Check if a contract was deployed by the factory
- Retrieve deployed contract addresses by index

### 4. **Security Features**
- Ownable: Only owner can update class hashes and upgrade
- Upgradeable: Factory contract can be upgraded
- Event logging for all deployments and updates

## Architecture

```
CMTATFactory
├── OwnableComponent (access control)
├── UpgradeableComponent (upgradeability)
└── Storage
    ├── standard_class_hash: ClassHash
    ├── debt_class_hash: ClassHash
    ├── light_class_hash: ClassHash
    ├── deployment_count: u256
    ├── deployments: LegacyMap<u256, ContractAddress>
    └── is_deployed: LegacyMap<ContractAddress, bool>
```

## Interface

### Factory Configuration

#### `get_standard_class_hash() -> ClassHash`
Returns the stored class hash for Standard CMTAT.

#### `get_debt_class_hash() -> ClassHash`
Returns the stored class hash for Debt CMTAT.

#### `get_light_class_hash() -> ClassHash`
Returns the stored class hash for Light CMTAT.

#### `set_standard_class_hash(class_hash: ClassHash)`
Updates the Standard CMTAT class hash. **Owner only**.

#### `set_debt_class_hash(class_hash: ClassHash)`
Updates the Debt CMTAT class hash. **Owner only**.

#### `set_light_class_hash(class_hash: ClassHash)`
Updates the Light CMTAT class hash. **Owner only**.

### Deployment Functions

#### `deploy_standard_cmtat(...) -> ContractAddress`
Deploys a new Standard CMTAT contract instance.

**Parameters:**
- `admin`: Initial admin address
- `name`: Token name
- `symbol`: Token symbol
- `initial_supply`: Initial token supply
- `recipient`: Address to receive initial supply
- `terms`: Terms identifier
- `information`: Additional information
- `salt`: Salt for address calculation

**Returns:** Address of deployed contract

**Emits:** `StandardCMTATDeployed`

#### `deploy_debt_cmtat(...) -> ContractAddress`
Deploys a new Debt CMTAT contract instance.

**Parameters:**
- `admin`: Initial admin address
- `name`: Token name
- `symbol`: Token symbol
- `initial_supply`: Initial token supply
- `recipient`: Address to receive initial supply
- `terms`: Terms identifier
- `isin`: International Securities Identification Number
- `maturity_date`: Debt maturity date (Unix timestamp)
- `interest_rate`: Interest rate (basis points as u256)
- `par_value`: Par value of the debt instrument
- `rule_engine`: Address of rule engine contract (or zero address)
- `snapshot_engine`: Address of snapshot engine contract (or zero address)
- `salt`: Salt for address calculation

**Returns:** Address of deployed contract

**Emits:** `DebtCMTATDeployed`

#### `deploy_light_cmtat(...) -> ContractAddress`
Deploys a new Light CMTAT contract instance.

**Parameters:**
- `admin`: Initial admin address
- `name`: Token name
- `symbol`: Token symbol
- `initial_supply`: Initial token supply
- `recipient`: Address to receive initial supply
- `terms`: Terms identifier
- `salt`: Salt for address calculation

**Returns:** Address of deployed contract

**Emits:** `LightCMTATDeployed`

### Query Functions

#### `get_deployment_count() -> u256`
Returns the total number of contracts deployed by this factory.

#### `get_deployment_at_index(index: u256) -> ContractAddress`
Returns the contract address at the specified index.

#### `is_deployed_by_factory(contract_address: ContractAddress) -> bool`
Checks if a contract was deployed by this factory.

## Events

### `StandardCMTATDeployed`
Emitted when a Standard CMTAT is deployed.
```cairo
struct StandardCMTATDeployed {
    contract_address: ContractAddress,  // indexed
    deployer: ContractAddress,          // indexed
    name: ByteArray,
    symbol: ByteArray,
    admin: ContractAddress,
}
```

### `DebtCMTATDeployed`
Emitted when a Debt CMTAT is deployed.
```cairo
struct DebtCMTATDeployed {
    contract_address: ContractAddress,  // indexed
    deployer: ContractAddress,          // indexed
    name: ByteArray,
    symbol: ByteArray,
    admin: ContractAddress,
    isin: ByteArray,
}
```

### `LightCMTATDeployed`
Emitted when a Light CMTAT is deployed.
```cairo
struct LightCMTATDeployed {
    contract_address: ContractAddress,  // indexed
    deployer: ContractAddress,          // indexed
    name: ByteArray,
    symbol: ByteArray,
    admin: ContractAddress,
}
```

### `ClassHashUpdated`
Emitted when a class hash is updated.
```cairo
struct ClassHashUpdated {
    contract_type: felt252,
    old_class_hash: ClassHash,
    new_class_hash: ClassHash,
}
```

## Usage Examples

### Deploying the Factory

```cairo
// Deploy factory with initial class hashes
let factory_address = deploy_factory(
    owner_address,
    standard_class_hash,
    debt_class_hash,
    light_class_hash
);
```

### Deploying a Standard CMTAT

```cairo
let token_address = factory.deploy_standard_cmtat(
    admin: admin_address,
    name: "My Security Token",
    symbol: "MST",
    initial_supply: 1000000_u256,
    recipient: recipient_address,
    terms: 'ipfs://...',
    information: "Additional token information",
    salt: 0x123
);
```

### Deploying a Debt CMTAT

```cairo
let debt_token_address = factory.deploy_debt_cmtat(
    admin: admin_address,
    name: "Corporate Bond Token",
    symbol: "CBT",
    initial_supply: 10000_u256,
    recipient: recipient_address,
    terms: 'ipfs://...',
    isin: "US1234567890",
    maturity_date: 1735689600_u64,  // Jan 1, 2025
    interest_rate: 500_u256,         // 5% (500 basis points)
    par_value: 1000_u256,            // $1000 par value
    rule_engine: rule_engine_address,
    snapshot_engine: snapshot_engine_address,
    salt: 0x456
);
```

### Deploying a Light CMTAT

```cairo
let light_token_address = factory.deploy_light_cmtat(
    admin: admin_address,
    name: "Simple Security Token",
    symbol: "SST",
    initial_supply: 500000_u256,
    recipient: recipient_address,
    terms: 'ipfs://...',
    salt: 0x789
);
```

### Updating Class Hashes (Owner Only)

```cairo
// Update Standard CMTAT implementation
factory.set_standard_class_hash(new_standard_class_hash);

// Update Debt CMTAT implementation
factory.set_debt_class_hash(new_debt_class_hash);

// Update Light CMTAT implementation
factory.set_light_class_hash(new_light_class_hash);
```

### Querying Deployments

```cairo
// Get total deployment count
let count = factory.get_deployment_count();

// Get contract at specific index
let contract_address = factory.get_deployment_at_index(5);

// Check if contract was deployed by factory
let is_deployed = factory.is_deployed_by_factory(contract_address);
```

## Deployment Process

### 1. Declare CMTAT Implementations
First, declare all three CMTAT contract classes to obtain their class hashes:

```bash
# Declare Standard CMTAT
sncast declare --contract-name StandardCMTAT

# Declare Debt CMTAT
sncast declare --contract-name DebtCMTAT

# Declare Light CMTAT
sncast declare --contract-name LightCMTAT
```

### 2. Declare and Deploy Factory
Declare and deploy the factory contract with the class hashes:

```bash
# Declare Factory
sncast declare --contract-name CMTATFactory

# Deploy Factory
sncast deploy \
    --class-hash <factory_class_hash> \
    --constructor-calldata <owner_address> <standard_class_hash> <debt_class_hash> <light_class_hash>
```

### 3. Deploy Tokens Using Factory
Use the factory to deploy token instances:

```bash
# Deploy via factory contract calls
sncast invoke \
    --contract-address <factory_address> \
    --function deploy_standard_cmtat \
    --calldata <admin> <name> <symbol> <initial_supply> <recipient> <terms> <information> <salt>
```

## Security Considerations

### Access Control
- Only the factory owner can update class hashes
- Only the factory owner can upgrade the factory contract
- Anyone can deploy tokens through the factory

### Salt Management
- Use unique salts for each deployment to avoid address collisions
- Salt can be derived from timestamp, counter, or other unique identifiers

### Class Hash Updates
- When updating class hashes, ensure the new implementations are compatible
- Old deployments will continue using their original class hashes
- Consider a transition period when upgrading implementations

### Deployment Tracking
- The factory maintains a registry of all deployed contracts
- This enables governance and monitoring of factory-deployed tokens
- Off-chain services can query deployments for discovery

## Best Practices

1. **Salt Generation**: Use unique, deterministic salts for reproducible deployments
2. **Constructor Validation**: Validate all constructor parameters before deployment
3. **Event Monitoring**: Monitor deployment events for security and tracking
4. **Class Hash Verification**: Always verify class hashes before updating
5. **Access Control**: Implement proper governance for factory ownership

## Integration with CMTAT Standards

The factory follows CMTAT (Capital Markets and Technology Association Token) standards by:

- Supporting all three CMTAT implementation levels
- Maintaining compatibility with CMTAT interfaces
- Enabling compliant token deployments
- Supporting regulatory requirements through proper role-based access control
- Tracking deployments for compliance and auditing

## Upgradeability

The factory contract is upgradeable using the OpenZeppelin Upgradeable component. This allows:

- Bug fixes without redeployment
- Feature additions over time
- Improved deployment logic
- Enhanced tracking capabilities

**Note:** Upgrading the factory does NOT affect already deployed tokens. Each token is an independent contract instance.

## Account Setup and Factory Interaction Guide

### Setting Up a Starknet Account

#### Option 1: Using Starknet Foundry (sncast)

1. **Create a new account:**
```bash
# Create account configuration
sncast account create \
    --name my_deployer \
    --url https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_7/YOUR_API_KEY

# Deploy the account on-chain
sncast account deploy \
    --name my_deployer \
    --max-fee 0.01
```

2. **Configure snfoundry.toml:**
```toml
[sncast.my_profile]
account = "my_deployer"
accounts-file = "~/.starknet_accounts/starknet_open_zeppelin_accounts.json"
url = "https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_7/YOUR_API_KEY"
```

3. **Fund your account:**
   - Get testnet tokens from [Starknet Faucet](https://faucet.goerli.starknet.io/) or [Blastapi Faucet](https://blastapi.io/faucets/starknet-sepolia-eth)
   - You'll need STRK tokens for transaction fees

#### Option 2: Using Starkli

1. **Create a signer:**
```bash
starkli signer keystore new ~/.starknet-wallets/keystore.json
```

2. **Create an account:**
```bash
starkli account oz init ~/.starknet-accounts/account.json
```

3. **Deploy the account:**
```bash
starkli account deploy ~/.starknet-accounts/account.json
```

#### Option 3: In a Bastion/Server Environment

For deployment in a bastion or CI/CD environment:

1. **Store credentials securely:**
```bash
# Create a dedicated directory for Starknet credentials
mkdir -p ~/.starknet_accounts
chmod 700 ~/.starknet_accounts

# Store your account JSON securely
# Ensure the account file has restricted permissions
chmod 600 ~/.starknet_accounts/starknet_open_zeppelin_accounts.json
```

2. **Use environment variables for sensitive data:**
```bash
export STARKNET_ACCOUNT=my_deployer
export STARKNET_RPC=https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_7/YOUR_API_KEY
export ACCOUNT_FILE=~/.starknet_accounts/starknet_open_zeppelin_accounts.json
```

3. **Create a deployment script:**
```bash
#!/bin/bash
set -e

# Load environment variables
source .env

# Deploy using sncast
sncast --account $STARKNET_ACCOUNT \
       --url $STARKNET_RPC \
       deploy --class-hash $FACTORY_CLASS_HASH \
       --constructor-calldata $OWNER_ADDRESS $STANDARD_CLASS_HASH $DEBT_CLASS_HASH $LIGHT_CLASS_HASH
```

### Interacting with the Factory

Once the factory is deployed, you can use it to deploy CMTAT tokens:

#### Deploying a Standard CMTAT

```bash
# Set variables
FACTORY_ADDRESS=0x07c9511c4c88b4286175c0d577d62535ae5ce9465322eaccd7c31c3e87a43d8e
ADMIN_ADDRESS=0x77a4f3a1404376cae3ea220ce3ce43ecfdbf9317b61c1b26930976179a8e302

# Deploy via factory using --arguments (recommended)
sncast --profile factory_deployer invoke \
    --contract-address $FACTORY_ADDRESS \
    --function deploy_standard_cmtat \
    --arguments '$ADMIN_ADDRESS, 
                  "My Security Token", 
                  "MST", 
                  1000000_u256, 
                  $ADMIN_ADDRESS, 
                  0x697066733a2f2f516d4578616d706c65, 
                  "Company stock token", 
                  12345'
```

**Note:** Use the `--arguments` flag with proper type suffixes (`_u256`) instead of manually splitting u256 values into low/high components. The `--arguments` flag automatically handles serialization based on the contract's ABI.

#### Deploying a Debt CMTAT

```bash
# Deploy via factory using --arguments (recommended)
sncast --profile factory_deployer invoke \
    --contract-address $FACTORY_ADDRESS \
    --function deploy_debt_cmtat \
    --arguments '$ADMIN_ADDRESS, 
                  "Corporate Bond Token", 
                  "CBT", 
                  500000_u256, 
                  $ADMIN_ADDRESS, 
                  0x697066733a2f2f516d4578616d706c65, 
                  "US1234567890", 
                  1735689600, 
                  500_u256, 
                  1000_u256, 
                  0x0, 
                  0x0, 
                  23456'
```

**Note:** All u256 values (initial_supply, interest_rate, par_value) should use the `_u256` suffix.

#### Deploying a Light CMTAT

```bash
# Deploy via factory using --arguments (recommended)
sncast --profile factory_deployer invoke \
    --contract-address $FACTORY_ADDRESS \
    --function deploy_light_cmtat \
    --arguments '$ADMIN_ADDRESS, 
                  "Simple Security Token", 
                  "SST", 
                  250000_u256, 
                  $ADMIN_ADDRESS, 
                  0x697066733a2f2f516d4578616d706c65, 
                  34567'
```

#### Querying Factory Information

```bash
# Get deployment count
sncast --profile factory_deployer call \
    --contract-address $FACTORY_ADDRESS \
    --function get_deployment_count

# Get deployed contract at specific index
sncast --profile factory_deployer call \
    --contract-address $FACTORY_ADDRESS \
    --function get_deployment_at_index \
    --calldata 0 0  # index as u256 (low, high)

# Check if contract was deployed by factory
sncast --profile factory_deployer call \
    --contract-address $FACTORY_ADDRESS \
    --function is_deployed_by_factory \
    --calldata <CONTRACT_ADDRESS>

# Get class hashes
sncast --profile factory_deployer call \
    --contract-address $FACTORY_ADDRESS \
    --function get_standard_class_hash

sncast --profile factory_deployer call \
    --contract-address $FACTORY_ADDRESS \
    --function get_debt_class_hash

sncast --profile factory_deployer call \
    --contract-address $FACTORY_ADDRESS \
    --function get_light_class_hash
```

### Using Cairo MCP for Semantic Search

You can use the Cairo Context MCP server to search for examples and documentation:

```bash
# Search for factory deployment examples
cline "find examples of deploying contracts using factory pattern in Cairo"

# Get information about CMTAT standards
cline "explain CMTAT token standards and compliance requirements"

# Find implementation details
cline "show me how to properly format constructor calldata for CMTAT deployment"
```

### Best Practices for Production Deployment

1. **Security:**
   - Never commit private keys or account files to version control
   - Use hardware wallets or secure key management systems for mainnet
   - Implement multi-sig for factory ownership on mainnet
   - Audit all contracts before mainnet deployment

2. **Testing:**
   - Test all deployments on Sepolia testnet first
   - Verify all constructor parameters before deployment
   - Test factory upgrade mechanisms
   - Monitor gas costs and optimize if needed

3. **Monitoring:**
   - Set up event listeners for deployment events
   - Track all deployed contracts in a database
   - Monitor factory owner address for security
   - Set up alerts for unusual activity

4. **Documentation:**
   - Document all deployed contract addresses
   - Keep a changelog of factory upgrades
   - Maintain deployment scripts in version control
   - Document parameter choices and rationale

## Deployment Log

### Sepolia Testnet - November 13, 2025

**Declared Class Hashes:**

| Contract Type | Class Hash | Transaction Hash | Explorer Link |
|--------------|------------|------------------|---------------|
| CMTATFactory | `0x642690cd7238eeee0bb2b7d7018f93b8b70ce746d5dd27e1eb686f4978b18eb` | `0x6bda05c4183358ca3e2fcb4d0c6af43a3654a7dbd8e81e17a88b6a0f5bb2d82` | [View](https://sepolia.starkscan.co/class/0x0642690cd7238eeee0bb2b7d7018f93b8b70ce746d5dd27e1eb686f4978b18eb) |
| StandardCMTAT | `0x63915780ef156861eb27e71cf701a9c48859ec78793727a673ba8c690db62bc` | `0x62bbebd4360afac3192b1d6bf6b2a7d6ca0174532e8de761b57070d6e701da0` | [View](https://sepolia.starkscan.co/class/0x063915780ef156861eb27e71cf701a9c48859ec78793727a673ba8c690db62bc) |
| DebtCMTAT | `0x38b7e98d854643d175bf4ccb3758542a1fcea75721705969bdfc1b69ba6e07e` | `0x36802b0b2333e5825160df8fe3f917fc0a82e7f9f03fbf2ac187bb2499370b7` | [View](https://sepolia.starkscan.co/class/0x038b7e98d854643d175bf4ccb3758542a1fcea75721705969bdfc1b69ba6e07e) |
| LightCMTAT | `0x4bfad6e822fd118c59ac4820b05235a1c54bd6d2c15c8b889b365bb8334ab3d` | `0x5d0ae8c67a0002b58a30894393fe86a0eb2ecf88f93312b80acb8fa117e501a` | [View](https://sepolia.starkscan.co/class/0x04bfad6e822fd118c59ac4820b05235a1c54bd6d2c15c8b889b365bb8334ab3d) |

**Account Used:**
- Address: `0x77a4f3a1404376cae3ea220ce3ce43ecfdbf9317b61c1b26930976179a8e302`
- Profile: `factory_deployer`

**Network:**
- Network: Starknet Sepolia Testnet
- RPC: `https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_7/...`

**Factory Deployment:**

| Item | Value | Explorer Link |
|------|-------|---------------|
| Factory Address | `0x07c9511c4c88b4286175c0d577d62535ae5ce9465322eaccd7c31c3e87a43d8e` | [View](https://sepolia.starkscan.co/contract/0x07c9511c4c88b4286175c0d577d62535ae5ce9465322eaccd7c31c3e87a43d8e) |
| Deploy Transaction | `0x046adc6e1c71631af2d209ee9a35677a59e6b6cb56a75059b06a48bfa2088ab4` | [View](https://sepolia.starkscan.co/tx/0x046adc6e1c71631af2d209ee9a35677a59e6b6cb56a75059b06a48bfa2088ab4) |
| Owner | `0x77a4f3a1404376cae3ea220ce3ce43ecfdbf9317b61c1b26930976179a8e302` | - |

**Test Deployments via Factory:**

| Contract Type | Transaction Hash | Parameters Used |
|---------------|------------------|-----------------|
| Standard CMTAT | `0x04c30c92b58242d2f6868180a4d94ad7365197fcfa9db03939bfd72686ed573f` | [View Details](#test-deployment-1-standard-cmtat) |
| Debt CMTAT | `0x02d8d0fccd1b420a92b39ec11d3cb20884e2c0511580b0a681affa0584543cd1` | [View Details](#test-deployment-2-debt-cmtat) |
| Light CMTAT | `0x00b1fd4f2e10c57775a69e9e45cf452eaf5c0574ca7e59e6a71799de91764627` | [View Details](#test-deployment-3-light-cmtat) |

### Test Deployment 1: Standard CMTAT

**Command:**
```bash
sncast --profile factory_deployer invoke \
    --contract-address 0x07c9511c4c88b4286175c0d577d62535ae5ce9465322eaccd7c31c3e87a43d8e \
    --function deploy_standard_cmtat \
    --arguments '0x77a4f3a1404376cae3ea220ce3ce43ecfdbf9317b61c1b26930976179a8e302, 
                  "Test Standard CMTAT", 
                  "TSTC", 
                  1000000_u256, 
                  0x77a4f3a1404376cae3ea220ce3ce43ecfdbf9317b61c1b26930976179a8e302, 
                  0x74657374, 
                  "Test Description", 
                  12345'
```

**Parameters Explained:**
- `admin`: `0x77a4f3a1404376cae3ea220ce3ce43ecfdbf9317b61c1b26930976179a8e302` (deployer account)
- `name`: `"Test Standard CMTAT"` (token name as ByteArray)
- `symbol`: `"TSTC"` (token symbol as ByteArray)
- `initial_supply`: `1000000_u256` (1 million tokens with `_u256` suffix)
- `recipient`: `0x77a4f3a1404376cae3ea220ce3ce43ecfdbf9317b61c1b26930976179a8e302` (same as admin)
- `terms`: `0x74657374` (felt252 - represents "test" in hex)
- `information`: `"Test Description"` (additional info as ByteArray)
- `salt`: `12345` (unique salt for deterministic address)

**Result:** [View Transaction](https://sepolia.starkscan.co/tx/0x04c30c92b58242d2f6868180a4d94ad7365197fcfa9db03939bfd72686ed573f)

### Test Deployment 2: Debt CMTAT

**Command:**
```bash
sncast --profile factory_deployer invoke \
    --contract-address 0x07c9511c4c88b4286175c0d577d62535ae5ce9465322eaccd7c31c3e87a43d8e \
    --function deploy_debt_cmtat \
    --arguments '0x77a4f3a1404376cae3ea220ce3ce43ecfdbf9317b61c1b26930976179a8e302, 
                  "Test Debt CMTAT", 
                  "TDBT", 
                  500000_u256, 
                  0x77a4f3a1404376cae3ea220ce3ce43ecfdbf9317b61c1b26930976179a8e302, 
                  0x64656274, 
                  "US1234567890", 
                  1735689600, 
                  500_u256, 
                  1000_u256, 
                  0x0, 
                  0x0, 
                  23456'
```

**Parameters Explained:**
- `admin`: `0x77a4f3a1404376cae3ea220ce3ce43ecfdbf9317b61c1b26930976179a8e302`
- `name`: `"Test Debt CMTAT"` (ByteArray)
- `symbol`: `"TDBT"` (ByteArray)
- `initial_supply`: `500000_u256` (500k tokens)
- `recipient`: `0x77a4f3a1404376cae3ea220ce3ce43ecfdbf9317b61c1b26930976179a8e302`
- `terms`: `0x64656274` (felt252 - "debt" in hex)
- `isin`: `"US1234567890"` (ISIN as ByteArray)
- `maturity_date`: `1735689600` (u64 Unix timestamp - Jan 1, 2025)
- `interest_rate`: `500_u256` (5% as 500 basis points)
- `par_value`: `1000_u256` ($1000 par value)
- `rule_engine`: `0x0` (zero address - not using rule engine)
- `snapshot_engine`: `0x0` (zero address - not using snapshot engine)
- `salt`: `23456`

**Result:** [View Transaction](https://sepolia.starkscan.co/tx/0x02d8d0fccd1b420a92b39ec11d3cb20884e2c0511580b0a681affa0584543cd1)

### Test Deployment 3: Light CMTAT

**Command:**
```bash
sncast --profile factory_deployer invoke \
    --contract-address 0x07c9511c4c88b4286175c0d577d62535ae5ce9465322eaccd7c31c3e87a43d8e \
    --function deploy_light_cmtat \
    --arguments '0x77a4f3a1404376cae3ea220ce3ce43ecfdbf9317b61c1b26930976179a8e302, 
                  "Test Light CMTAT", 
                  "TLGT", 
                  250000_u256, 
                  0x77a4f3a1404376cae3ea220ce3ce43ecfdbf9317b61c1b26930976179a8e302, 
                  0x6c69676874, 
                  34567'
```

**Parameters Explained:**
- `admin`: `0x77a4f3a1404376cae3ea220ce3ce43ecfdbf9317b61c1b26930976179a8e302`
- `name`: `"Test Light CMTAT"` (ByteArray)
- `symbol`: `"TLGT"` (ByteArray)
- `initial_supply`: `250000_u256` (250k tokens)
- `recipient`: `0x77a4f3a1404376cae3ea220ce3ce43ecfdbf9317b61c1b26930976179a8e302`
- `terms`: `0x6c69676874` (felt252 - "light" in hex)
- `salt`: `34567`

**Result:** [View Transaction](https://sepolia.starkscan.co/tx/0x00b1fd4f2e10c57775a69e9e45cf452eaf5c0574ca7e59e6a71799de91764627)

### Important Notes on Parameter Formatting

1. **ByteArray (Strings)**: Use double quotes `"My String"`
2. **u256 Values**: Add the `_u256` suffix to ensure proper type, e.g., `1000000_u256`
3. **u64 Values**: Regular numbers work, e.g., `1735689600`
4. **felt252**: Can be hex (with `0x` prefix) or decimal
5. **ContractAddress**: Always use hex format with `0x` prefix
6. **Zero Address**: Use `0x0` when no address is needed (e.g., for optional engines)

### Verifying Deployments

Query the factory to verify deployments:

```bash
# Get total number of deployments (should be 3)
sncast --profile factory_deployer call \
    --contract-address 0x07c9511c4c88b4286175c0d577d62535ae5ce9465322eaccd7c31c3e87a43d8e \
    --function get_deployment_count

# Get first deployment address
sncast --profile factory_deployer call \
    --contract-address 0x07c9511c4c88b4286175c0d577d62535ae5ce9465322eaccd7c31c3e87a43d8e \
    --function get_deployment_at_index \
    --arguments '0_u256'
```

## License

This contract is released under the MPL-2.0 license.

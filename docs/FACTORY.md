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

## License

This contract is released under the MPL-2.0 license.

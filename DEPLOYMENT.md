# CMTAT Factory Deployment Guide

This guide walks you through deploying and testing the CMTAT Factory on Starknet using your Alchemy API key and wallet accounts.

## Prerequisites

1. **Alchemy API Key**: You need a Starknet Sepolia API key from Alchemy
2. **Wallet Setup**: Accounts configured in the specified paths:
   - `~/.starknet-accounts/account.json`
   - `~/.starknet-wallets/keystore.json`
3. **Dependencies**: 
   - `scarb` for building Cairo contracts
   - `sncast` for deploying to Starknet

## Setup

### 1. Configure Environment Variables

Edit the `.env` file and replace `your_alchemy_api_key_here` with your actual Alchemy API key:

```bash
# Edit .env file
nano .env

# Replace the line:
ALCHEMY_API_KEY=your_alchemy_api_key_here
# With your actual API key:
ALCHEMY_API_KEY=your_actual_api_key_from_alchemy
```

### 2. Verify Wallet Configuration

Make sure your account is properly configured:

```bash
# Check available accounts
sncast account list

# The script expects the account named "deployer_foundry"
# If you have a different account name, update snfoundry.toml
```

## Deployment Process

### Step 1: Deploy the Factory

Choose your deployment method and run the appropriate script:

**Option 1: Deploy with sncast (recommended for new deployments)**
```bash
./scripts/deploy_factory_sncast.sh
```
*Uses sncast to declare all contracts and deploy the factory. Best for fresh deployments where contracts haven't been declared yet.*

**Option 2: Deploy with starkli (simple deployment with known class hashes)**
```bash
./scripts/deploy_factory_starkli.sh
```
*Uses starkli with pre-declared class hashes. Faster if you're using known, already-declared implementations.*

Alternatively, you can use the wrapper script that will prompt you to choose:
```bash
./scripts/deploy_factory.sh
```

The deployment script will:
1. Build all Cairo contracts
2. Declare StandardCMTAT, DebtCMTAT, and LightCMTAT contracts
3. Declare the CMTATFactory contract
4. Deploy the factory with the obtained class hashes
5. Update `.env` with deployment results

### Step 2: Test All Deployments

Run the comprehensive test script:

```bash
./scripts/test_factory.sh
```

This script will:
1. Query factory configuration
2. Deploy a Standard CMTAT via factory
3. Deploy a Light CMTAT via factory  
4. Deploy a Debt CMTAT via factory
5. Test deployment tracking functions

## Expected Output

### Deployment Script Output

```
=== CMTAT Factory Deployment Script ===

✓ Environment variables loaded
Network: sepolia
Account: deployer_foundry

=== Building Contracts ===
✓ Build complete

=== Declaring StandardCMTAT ===
✓ Class hash: 0x1234...

=== Declaring DebtCMTAT ===
✓ Class hash: 0x5678...

=== Declaring LightCMTAT ===
✓ Class hash: 0x9abc...

=== Declaring CMTATFactory ===
✓ Class hash: 0xdef0...

=== Deploying CMTAT Factory ===
✓ Factory deployed at: 0x1357...

🎉 CMTAT Factory Deployment Complete!
```

### Test Script Output

```
=== CMTAT Factory Testing Script ===

✓ Using Factory at: 0x1357...

=== Test 1: Query Factory Configuration ===
✓ Standard class hash returned
✓ Debt class hash returned
✓ Light class hash returned
✓ Initial deployment count: 0

=== Test 2: Deploy Standard CMTAT ===
✓ Transaction hash: 0x2468...

=== Test 3: Deploy Light CMTAT ===
✓ Transaction hash: 0x3579...

=== Test 4: Deploy Debt CMTAT ===
✓ Transaction hash: 0x4680...

=== Test 5: Query Deployment Tracking ===
✓ Deployment count: 3
✓ Deployment at index 0: Standard CMTAT
✓ Deployment at index 1: Light CMTAT
✓ Deployment at index 2: Debt CMTAT

🎉 Factory Testing Complete!
```

## Troubleshooting

### Common Issues

1. **API Key Error**: Make sure your Alchemy API key is correct and has Starknet access
2. **Account Not Found**: Verify your account files exist and are properly configured
3. **Network Issues**: Check your internet connection and Alchemy service status
4. **Gas Issues**: Ensure your account has sufficient ETH for gas fees

### Debug Commands

```bash
# Check account balance
sncast call --contract-address 0x... --function "balanceOf" --calldata "your_address"

# Verify contract deployment
sncast call --contract-address "factory_address" --function "get_deployment_count"

# Check transaction status
starkli transaction-status 0x... --network sepolia
```

## Contract Addresses

After successful deployment, you'll find all contract addresses in the `.env` file:

- `FACTORY_ADDRESS`: The main factory contract
- `STANDARD_CMTAT_CLASS_HASH`: Class hash for Standard CMTAT
- `DEBT_CMTAT_CLASS_HASH`: Class hash for Debt CMTAT
- `LIGHT_CMTAT_CLASS_HASH`: Class hash for Light CMTAT

## Security Notes

- Never commit your `.env` file (it's in `.gitignore`)
- Keep your API keys secure
- Use testnet for development and testing
- Verify all transactions on [Starkscan](https://sepolia.starkscan.co/)

## Next Steps

1. **Integration Testing**: Test token functionality post-deployment
2. **Frontend Integration**: Connect your dApp to the deployed factory
3. **Mainnet Deployment**: After thorough testing, deploy to mainnet
4. **Monitoring**: Set up monitoring for your deployed contracts
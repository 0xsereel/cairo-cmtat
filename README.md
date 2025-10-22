# CMTAT ERC20 Token on Starknet

A production-ready ERC20 token implementation for Starknet using OpenZeppelin contracts. This project includes a comprehensive deployment script that automatically returns the block explorer URL upon successful deployment.

## Features

- ✅ Standard ERC20 token implementation
- ✅ Built with OpenZeppelin Contracts for Cairo v0.13.0
- ✅ Compatible with Cairo 2.6.3 and Scarb 2.6.4
- ✅ Automated deployment script with block explorer URL
- ✅ Support for both Sepolia Testnet and Mainnet
- ✅ Initial supply of 1,000,000 tokens (18 decimals)
- ✅ Deployment details saved to JSON file

## Prerequisites

Before you begin, ensure you have the following installed:

1. **Scarb** - Cairo package manager
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh
   ```

2. **Starkli** - Starknet CLI tool
   ```bash
   curl https://get.starkli.sh | sh
   starkliup
   ```

3. **Starknet Account** - You need a funded account on either:
   - Sepolia Testnet (recommended for testing)
   - Mainnet (for production)

## Project Structure

```
cairo-cmtat/
├── Scarb.toml              # Project configuration
├── src/
│   └── lib.cairo           # ERC20 token contract
├── scripts/
│   └── deploy.sh           # Deployment script
└── README.md               # This file
```

## Quick Start

### 1. Build the Contract

```bash
scarb build
```

This will compile the Cairo contract and generate the contract class JSON files in the `target/dev/` directory.

### 2. Set Up Your Starknet Account

If you don't have a Starknet account yet, create one using Starkli:

```bash
# Create a new account
starkli account oz init ~/.starknet-accounts/account.json

# Deploy the account (you'll need to fund it first)
starkli account deploy ~/.starknet-accounts/account.json
```

### 3. Deploy the Token

Run the deployment script:

```bash
./scripts/deploy.sh
```

The script will:
1. Prompt you to select a network (Sepolia Testnet or Mainnet)
2. Ask for the recipient address (who will receive the initial token supply)
3. Request your account address and keystore path
4. Build, declare, and deploy the contract
5. Display the block explorer URL for your deployed contract
6. Save deployment details to `deployment.json`

## Deployment Script Details

The deployment script (`scripts/deploy.sh`) provides:

- **Interactive Network Selection**: Choose between Sepolia Testnet and Mainnet
- **Automated Build Process**: Compiles the contract before deployment
- **Class Declaration**: Declares the contract class on Starknet
- **Contract Deployment**: Deploys the contract with the specified recipient
- **Block Explorer Integration**: Returns the Voyager explorer URL for your contract
- **Deployment Logging**: Saves all deployment details to `deployment.json`

### Example Output

```
================================================
   CMTAT ERC20 Token Deployment Script
================================================

Select network:
1) Sepolia Testnet (default)
2) Mainnet
Enter choice [1-2] (default: 1): 1
Selected: Sepolia Testnet

Enter recipient address for initial token supply: 0x...
Enter your account address: 0x...
Enter path to your account keystore file: ~/.starknet-accounts/account.json

Step 1: Building the contract...
✓ Contract built successfully

Step 2: Declaring the contract class...
✓ Class hash: 0x...

Step 3: Deploying the contract...
✓ Contract deployed successfully!

================================================
   Deployment Successful!
================================================

Network: sepolia
Contract Address: 0x...
Class Hash: 0x...
Recipient: 0x...

Block Explorer URL:
https://sepolia.voyager.online/contract/0x...

Transaction Explorer:
https://sepolia.voyager.online/tx/0x...

================================================
Deployment details saved to deployment.json
```

## Token Details

- **Name**: CMTAT Token
- **Symbol**: CMTAT
- **Decimals**: 18 (standard)
- **Initial Supply**: 1,000,000 tokens (1,000,000 × 10^18 in smallest unit)

## Contract Interface

The contract implements the standard ERC20 interface:

- `name() -> felt252` - Returns the token name
- `symbol() -> felt252` - Returns the token symbol
- `decimals() -> u8` - Returns the number of decimals
- `total_supply() -> u256` - Returns the total token supply
- `balance_of(account: ContractAddress) -> u256` - Returns the balance of an account
- `allowance(owner: ContractAddress, spender: ContractAddress) -> u256` - Returns the allowance
- `transfer(recipient: ContractAddress, amount: u256) -> bool` - Transfers tokens
- `transfer_from(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool` - Transfers tokens from
- `approve(spender: ContractAddress, amount: u256) -> bool` - Approves spending

## Interacting with Your Deployed Token

After deployment, you can interact with your token using Starkli:

### Check Token Balance

```bash
starkli call <CONTRACT_ADDRESS> balance_of <ACCOUNT_ADDRESS> --rpc <RPC_URL>
```

### Transfer Tokens

```bash
starkli invoke <CONTRACT_ADDRESS> transfer <RECIPIENT> <AMOUNT_LOW> <AMOUNT_HIGH> \
  --account <YOUR_ACCOUNT> \
  --keystore <KEYSTORE_PATH> \
  --rpc <RPC_URL>
```

### Approve Spending

```bash
starkli invoke <CONTRACT_ADDRESS> approve <SPENDER> <AMOUNT_LOW> <AMOUNT_HIGH> \
  --account <YOUR_ACCOUNT> \
  --keystore <KEYSTORE_PATH> \
  --rpc <RPC_URL>
```

## Block Explorer

Once deployed, you can view your contract on Voyager:

- **Sepolia Testnet**: https://sepolia.voyager.online/contract/YOUR_CONTRACT_ADDRESS
- **Mainnet**: https://voyager.online/contract/YOUR_CONTRACT_ADDRESS

The explorer allows you to:
- View all transactions
- Check token holders
- Read contract state
- Verify the contract code

## Troubleshooting

### Build Issues

If you encounter build errors:
```bash
# Clean the build directory
rm -rf target/

# Rebuild
scarb build
```

### Deployment Issues

If deployment fails:
1. Ensure your account has sufficient funds for gas fees
2. Verify your account address and keystore path are correct
3. Check that you're connected to the correct network
4. Make sure Starkli is properly installed and configured

### Account Funding

For Sepolia Testnet, you can get test ETH from:
- [Starknet Faucet](https://starknet-faucet.vercel.app/)
- [Alchemy Faucet](https://www.alchemy.com/faucets/starknet-sepolia)

## Security Considerations

- **Private Keys**: Never share your keystore files or private keys
- **Testing**: Always test on Sepolia Testnet before deploying to Mainnet
- **Audits**: Consider getting a professional audit for production deployments
- **Initial Supply**: Review the initial token supply before deployment

## References

- [Starknet Documentation](https://docs.starknet.io/)
- [Cairo Book](https://book.cairo-lang.org/)
- [OpenZeppelin Cairo Contracts](https://github.com/OpenZeppelin/cairo-contracts)
- [Starkli Documentation](https://book.starkli.rs/)
- [Voyager Block Explorer](https://voyager.online/)

## License

MIT License - See LICENSE file for details

## Support

For issues and questions:
- Open an issue on the project repository
- Consult the Starknet community resources
- Review the Cairo and OpenZeppelin documentation

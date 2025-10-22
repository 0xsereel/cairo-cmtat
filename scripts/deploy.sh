#!/bin/bash

# CMTAT ERC20 Deployment Script
# This script deploys the ERC20 token to Starknet and returns the block explorer URL

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   CMTAT ERC20 Token Deployment Script${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check if starkli is installed
if ! command -v starkli &> /dev/null; then
    echo -e "${RED}Error: starkli is not installed${NC}"
    echo "Please install starkli: curl https://get.starkli.sh | sh"
    exit 1
fi

# Network selection
echo -e "${YELLOW}Select network:${NC}"
echo "1) Sepolia Testnet (default)"
echo "2) Mainnet"
read -p "Enter choice [1-2] (default: 1): " network_choice
network_choice=${network_choice:-1}

case $network_choice in
    1)
        NETWORK="sepolia"
        RPC_URL="https://starknet-sepolia.public.blastapi.io/rpc/v0_7"
        EXPLORER_URL="https://sepolia.voyager.online"
        echo -e "${GREEN}Selected: Sepolia Testnet${NC}"
        ;;
    2)
        NETWORK="mainnet"
        RPC_URL="https://starknet-mainnet.public.blastapi.io/rpc/v0_7"
        EXPLORER_URL="https://voyager.online"
        echo -e "${GREEN}Selected: Mainnet${NC}"
        ;;
    *)
        echo -e "${RED}Invalid choice. Defaulting to Sepolia Testnet${NC}"
        NETWORK="sepolia"
        RPC_URL="https://starknet-sepolia.public.blastapi.io/rpc/v0_7"
        EXPLORER_URL="https://sepolia.voyager.online"
        ;;
esac

echo ""

# Get recipient address
read -p "Enter recipient address for initial token supply: " RECIPIENT
if [ -z "$RECIPIENT" ]; then
    echo -e "${RED}Error: Recipient address is required${NC}"
    exit 1
fi

# Get account details
read -p "Enter your account address: " ACCOUNT_ADDRESS
if [ -z "$ACCOUNT_ADDRESS" ]; then
    echo -e "${RED}Error: Account address is required${NC}"
    exit 1
fi

read -p "Enter path to your account keystore file: " KEYSTORE_PATH
if [ -z "$KEYSTORE_PATH" ]; then
    echo -e "${RED}Error: Keystore path is required${NC}"
    exit 1
fi

if [ ! -f "$KEYSTORE_PATH" ]; then
    echo -e "${RED}Error: Keystore file not found at $KEYSTORE_PATH${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 1: Building the contract...${NC}"
scarb build

if [ ! -f "target/dev/cairo_cmtat_erc20_CMTAT_ERC20.compiled_contract_class.json" ]; then
    echo -e "${RED}Error: Contract class file not found after build${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Contract built successfully${NC}"
echo ""

echo -e "${BLUE}Step 2: Declaring the contract class...${NC}"
DECLARE_OUTPUT=$(starkli declare \
    target/dev/cairo_cmtat_erc20_CMTAT_ERC20.compiled_contract_class.json \
    --rpc $RPC_URL \
    --account $ACCOUNT_ADDRESS \
    --keystore $KEYSTORE_PATH 2>&1)

# Extract class hash from output
CLASS_HASH=$(echo "$DECLARE_OUTPUT" | grep -oP '(?<=Class hash declared:\s)0x[a-fA-F0-9]+' || echo "$DECLARE_OUTPUT" | grep -oP '(?<=Class hash:\s)0x[a-fA-F0-9]+' || echo "$DECLARE_OUTPUT" | grep -oP '0x[a-fA-F0-9]{64}')

if [ -z "$CLASS_HASH" ]; then
    echo -e "${YELLOW}Note: Class may already be declared. Checking output...${NC}"
    echo "$DECLARE_OUTPUT"
    # Try to extract from "already declared" message
    CLASS_HASH=$(echo "$DECLARE_OUTPUT" | grep -oP '0x[a-fA-F0-9]{64}' | head -1)
fi

if [ -z "$CLASS_HASH" ]; then
    echo -e "${RED}Error: Could not extract class hash${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Class hash: $CLASS_HASH${NC}"
echo ""

echo -e "${BLUE}Step 3: Deploying the contract...${NC}"
DEPLOY_OUTPUT=$(starkli deploy \
    $CLASS_HASH \
    $RECIPIENT \
    --rpc $RPC_URL \
    --account $ACCOUNT_ADDRESS \
    --keystore $KEYSTORE_PATH 2>&1)

# Extract contract address from output
CONTRACT_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -oP '(?<=Contract deployed:\s)0x[a-fA-F0-9]+' || echo "$DEPLOY_OUTPUT" | grep -oP '0x[a-fA-F0-9]{64}')

if [ -z "$CONTRACT_ADDRESS" ]; then
    echo -e "${RED}Error: Could not extract contract address${NC}"
    echo "$DEPLOY_OUTPUT"
    exit 1
fi

echo -e "${GREEN}✓ Contract deployed successfully!${NC}"
echo ""

# Display results
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}   Deployment Successful!${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${YELLOW}Network:${NC} $NETWORK"
echo -e "${YELLOW}Contract Address:${NC} $CONTRACT_ADDRESS"
echo -e "${YELLOW}Class Hash:${NC} $CLASS_HASH"
echo -e "${YELLOW}Recipient:${NC} $RECIPIENT"
echo ""
echo -e "${GREEN}Block Explorer URL:${NC}"
echo -e "${BLUE}$EXPLORER_URL/contract/$CONTRACT_ADDRESS${NC}"
echo ""
echo -e "${YELLOW}Transaction Explorer:${NC}"
echo -e "${BLUE}$EXPLORER_URL/tx/${CONTRACT_ADDRESS}${NC}"
echo ""
echo -e "${BLUE}================================================${NC}"

# Save deployment info to file
cat > deployment.json <<EOF
{
  "network": "$NETWORK",
  "contract_address": "$CONTRACT_ADDRESS",
  "class_hash": "$CLASS_HASH",
  "recipient": "$RECIPIENT",
  "explorer_url": "$EXPLORER_URL/contract/$CONTRACT_ADDRESS",
  "deployed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo -e "${GREEN}Deployment details saved to deployment.json${NC}"

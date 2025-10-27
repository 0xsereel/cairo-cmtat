#!/bin/bash

# CMTAT ERC20 Deployment Script
# This script deploys the ERC20 token to Starknet and returns the block explorer URL

set -e

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

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
        RPC_URL="${ALCHEMY_RPC_URL_SEPOLIA}"
        EXPLORER_URL="https://sepolia.voyager.online"
        echo -e "${GREEN}Selected: Sepolia Testnet${NC}"
        ;;
    2)
        NETWORK="mainnet"
        RPC_URL="${ALCHEMY_RPC_URL_MAINNET:-https://starknet-mainnet.public.blastapi.io}"
        EXPLORER_URL="https://voyager.online"
        echo -e "${GREEN}Selected: Mainnet${NC}"
        ;;
    *)
        echo -e "${RED}Invalid choice. Defaulting to Sepolia Testnet${NC}"
        NETWORK="sepolia"
        RPC_URL="${ALCHEMY_RPC_URL_SEPOLIA}"
        EXPLORER_URL="https://sepolia.voyager.online"
        ;;
esac

# Check if RPC URL is set
if [ -z "$RPC_URL" ]; then
    echo -e "${RED}Error: RPC URL not found. Please set ALCHEMY_RPC_URL_SEPOLIA in .env file${NC}"
    exit 1
fi

echo ""

# Get recipient address
read -p "Enter recipient address for initial token supply: " RECIPIENT
if [ -z "$RECIPIENT" ]; then
    echo -e "${RED}Error: Recipient address is required${NC}"
    exit 1
fi

# Get account details
read -p "Enter path to your account config file (e.g., ~/.starknet-accounts/account.json): " ACCOUNT_FILE
if [ -z "$ACCOUNT_FILE" ]; then
    echo -e "${RED}Error: Account file path is required${NC}"
    exit 1
fi

if [ ! -f "$ACCOUNT_FILE" ]; then
    echo -e "${RED}Error: Account file not found at $ACCOUNT_FILE${NC}"
    exit 1
fi

read -p "Enter path to your keystore file (e.g., ~/.starknet-wallets/keystore.json): " KEYSTORE_PATH
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

if [ ! -f "target/dev/cairo_cmtat_erc20_CMTAT_ERC20.contract_class.json" ]; then
    echo -e "${RED}Error: Contract class file not found after build${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Contract built successfully${NC}"
echo ""

echo -e "${BLUE}Step 2: Declaring the contract class...${NC}"
# Run declare command and save output to temporary file
starkli declare \
    target/dev/cairo_cmtat_erc20_CMTAT_ERC20.contract_class.json \
    --rpc $RPC_URL \
    --account $ACCOUNT_FILE \
    --keystore $KEYSTORE_PATH 2>&1 | tee /tmp/declare_output.txt

# Check for errors in declare output
if grep -q "Error:" /tmp/declare_output.txt || grep -q "exceed balance" /tmp/declare_output.txt; then
    echo ""
    echo -e "${RED}Error: Declaration failed!${NC}"
    echo -e "${YELLOW}Output from declare command:${NC}"
    cat /tmp/declare_output.txt
    echo ""
    echo -e "${YELLOW}Possible solutions:${NC}"
    echo "1. Add more STRK to your account (you need ~0.1-0.2 STRK for declaration)"
    echo "2. The class may already be declared - you can continue with the existing class hash"
    echo ""
    read -p "Enter class hash to continue (or press Ctrl+C to exit): " CLASS_HASH
    if [ -z "$CLASS_HASH" ]; then
        echo -e "${RED}Error: Class hash is required${NC}"
        exit 1
    fi
else
    # Extract class hash from output file (compatible with macOS grep)
    CLASS_HASH=$(grep "Class hash declared:" /tmp/declare_output.txt | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)

    if [ -z "$CLASS_HASH" ]; then
        CLASS_HASH=$(grep "Class hash:" /tmp/declare_output.txt | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)
    fi

    if [ -z "$CLASS_HASH" ]; then
        # Try to find the declaring class hash from the output
        CLASS_HASH=$(grep "Declaring Cairo 1 class:" /tmp/declare_output.txt | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)
    fi

    if [ -z "$CLASS_HASH" ]; then
        echo ""
        echo -e "${YELLOW}Note: Could not extract class hash from output.${NC}"
        echo -e "${YELLOW}Output from declare command:${NC}"
        cat /tmp/declare_output.txt
        echo ""
        read -p "Please enter the class hash manually (or press Ctrl+C to exit): " CLASS_HASH
        if [ -z "$CLASS_HASH" ]; then
            echo -e "${RED}Error: Class hash is required${NC}"
            exit 1
        fi
    fi
fi

echo ""
echo -e "${GREEN}✓ Class hash: $CLASS_HASH${NC}"
echo ""

echo -e "${BLUE}Step 3: Deploying the contract...${NC}"
# Run deploy command and save output to temporary file
starkli deploy \
    $CLASS_HASH \
    $RECIPIENT \
    --rpc $RPC_URL \
    --account $ACCOUNT_FILE \
    --keystore $KEYSTORE_PATH 2>&1 | tee /tmp/deploy_output.txt

# Store the exit code
DEPLOY_EXIT_CODE=$?

# Check for errors in the output
if grep -q "Error:" /tmp/deploy_output.txt; then
    echo ""
    echo -e "${RED}Error: Deployment failed!${NC}"
    echo -e "${YELLOW}Output from deploy command:${NC}"
    cat /tmp/deploy_output.txt
    echo ""
    exit 1
fi

# Extract contract address from output file (compatible with macOS grep)
# First try "Contract deployed:" message
CONTRACT_ADDRESS=$(grep "Contract deployed:" /tmp/deploy_output.txt | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)

# If not found, try "will be deployed at address" message (predicted address)
if [ -z "$CONTRACT_ADDRESS" ]; then
    CONTRACT_ADDRESS=$(grep "will be deployed at address" /tmp/deploy_output.txt | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)
fi

# If still not found, try to extract from transaction receipt
if [ -z "$CONTRACT_ADDRESS" ]; then
    CONTRACT_ADDRESS=$(grep "contract_address" /tmp/deploy_output.txt | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)
fi

if [ -z "$CONTRACT_ADDRESS" ]; then
    echo ""
    echo -e "${YELLOW}Note: Could not extract contract address from output.${NC}"
    echo -e "${YELLOW}Output from deploy command:${NC}"
    cat /tmp/deploy_output.txt
    echo ""
    read -p "Please enter the contract address manually (or press Ctrl+C to exit): " CONTRACT_ADDRESS
    if [ -z "$CONTRACT_ADDRESS" ]; then
        echo -e "${RED}Error: Contract address is required${NC}"
        exit 1
    fi
fi

echo ""
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
echo -e "${YELLOW}Transaction Hash:${NC}"
echo -e "${BLUE}Check recent transactions from your deployer account${NC}"
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

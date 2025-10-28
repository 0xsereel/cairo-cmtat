#!/bin/bash
# SPDX-License-Identifier: MPL-2.0
# Deployment script for CMTAT Rule and Snapshot Engines

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NETWORK="${NETWORK:-sepolia}"
ACCOUNT="${ACCOUNT:-default}"
ACCOUNT_FILE="${ACCOUNT_FILE:-$HOME/.starknet-accounts/account.json}"
KEYSTORE="${KEYSTORE:-$HOME/.starknet-wallets/keystore.json}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  CMTAT Engine Deployment Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --network NETWORK          Starknet network (default: sepolia)"
    echo "  --account ACCOUNT          Account name (default: default)"
    echo "  --account-file FILE        Account config file (default: ~/.starknet-accounts/account.json)"
    echo "  --keystore FILE            Keystore file (default: ~/.starknet-wallets/keystore.json)"
    echo "  --engine TYPE              Engine type: rule or snapshot"
    echo "  --token-address ADDRESS    Token contract address"
    echo "  --owner ADDRESS            Engine owner address"
    echo "  --max-balance AMOUNT       Max balance for rule engine (optional)"
    echo "  --help                     Display this help message"
    echo ""
    echo "Examples:"
    echo "  Deploy Rule Engine:"
    echo "    $0 --engine rule --token-address 0x123... --owner 0x456..."
    echo ""
    echo "  Deploy Snapshot Engine:"
    echo "    $0 --engine snapshot --token-address 0x123... --owner 0x456..."
    exit 1
}

# Parse command line arguments
ENGINE_TYPE=""
TOKEN_ADDRESS=""
OWNER_ADDRESS=""
MAX_BALANCE="0"

while [[ $# -gt 0 ]]; do
    case $1 in
        --network)
            NETWORK="$2"
            shift 2
            ;;
        --account)
            ACCOUNT="$2"
            shift 2
            ;;
        --account-file)
            ACCOUNT_FILE="$2"
            shift 2
            ;;
        --keystore)
            KEYSTORE="$2"
            shift 2
            ;;
        --engine)
            ENGINE_TYPE="$2"
            shift 2
            ;;
        --token-address)
            TOKEN_ADDRESS="$2"
            shift 2
            ;;
        --owner)
            OWNER_ADDRESS="$2"
            shift 2
            ;;
        --max-balance)
            MAX_BALANCE="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Validate required parameters
if [ -z "$ENGINE_TYPE" ]; then
    echo -e "${RED}Error: --engine is required${NC}"
    usage
fi

if [ -z "$TOKEN_ADDRESS" ]; then
    echo -e "${RED}Error: --token-address is required${NC}"
    usage
fi

if [ -z "$OWNER_ADDRESS" ]; then
    echo -e "${RED}Error: --owner is required${NC}"
    usage
fi

# Set explorer URL based on network
if [ "$NETWORK" = "mainnet" ]; then
    EXPLORER_URL="https://voyager.online"
else
    EXPLORER_URL="https://sepolia.voyager.online"
fi

echo -e "${YELLOW}Deployment Configuration:${NC}"
echo "  Network: $NETWORK"
echo "  Account: $ACCOUNT"
echo "  Engine Type: $ENGINE_TYPE"
echo "  Token Address: $TOKEN_ADDRESS"
echo "  Owner: $OWNER_ADDRESS"
if [ "$ENGINE_TYPE" = "rule" ]; then
    echo "  Max Balance: $MAX_BALANCE"
fi
echo ""

# Build the project
echo -e "${BLUE}Step 1: Building the contract...${NC}"
scarb build

if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Contract built successfully${NC}"
echo ""

# Determine contract file based on engine type
case "$ENGINE_TYPE" in
    rule)
        CONTRACT_FILE="cairo_cmtat_WhitelistRuleEngine.contract_class.json"
        CONTRACT_NAME="WhitelistRuleEngine"
        ;;
    snapshot)
        CONTRACT_FILE="cairo_cmtat_SimpleSnapshotEngine.contract_class.json"
        CONTRACT_NAME="SimpleSnapshotEngine"
        ;;
    *)
        echo -e "${RED}Invalid engine type: $ENGINE_TYPE${NC}"
        echo "Valid types: rule, snapshot"
        exit 1
        ;;
esac

# Deploy the engine
echo -e "${BLUE}Step 2: Declaring the contract class...${NC}"

# Declare the contract and save output
if [ -f "$ACCOUNT_FILE" ] && [ -f "$KEYSTORE" ]; then
    starkli declare \
        target/dev/$CONTRACT_FILE \
        --network "$NETWORK" \
        --account "$ACCOUNT_FILE" \
        --keystore "$KEYSTORE" 2>&1 | tee /tmp/engine_declare_output.txt
else
    starkli declare \
        target/dev/$CONTRACT_FILE \
        --network "$NETWORK" \
        --account "$ACCOUNT" 2>&1 | tee /tmp/engine_declare_output.txt
fi

# Check for errors in declare output
if grep -q "Error:" /tmp/engine_declare_output.txt || grep -q "exceed balance" /tmp/engine_declare_output.txt; then
    echo ""
    echo -e "${RED}Error: Declaration failed!${NC}"
    echo -e "${YELLOW}Output from declare command:${NC}"
    cat /tmp/engine_declare_output.txt
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
    # Extract class hash from output - compatible with macOS grep
    CLASS_HASH=$(grep "Class hash declared:" /tmp/engine_declare_output.txt | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)

    if [ -z "$CLASS_HASH" ]; then
        CLASS_HASH=$(grep "Class hash:" /tmp/engine_declare_output.txt | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)
    fi

    if [ -z "$CLASS_HASH" ]; then
        CLASS_HASH=$(grep "Declaring Cairo 1 class:" /tmp/engine_declare_output.txt | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)
    fi

    if [ -z "$CLASS_HASH" ]; then
        echo ""
        echo -e "${YELLOW}Note: Could not extract class hash from output.${NC}"
        echo -e "${YELLOW}Output from declare command:${NC}"
        cat /tmp/engine_declare_output.txt
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

# Wait for declaration to be confirmed
echo -e "${YELLOW}Waiting for declaration to be confirmed on-chain...${NC}"
sleep 5
echo -e "${GREEN}✓ Declaration should be confirmed${NC}"
echo ""

# Deploy the contract with appropriate parameters
echo -e "${BLUE}Step 3: Deploying the contract...${NC}"

if [ -f "$ACCOUNT_FILE" ] && [ -f "$KEYSTORE" ]; then
    if [ "$ENGINE_TYPE" = "rule" ]; then
        starkli deploy \
            "$CLASS_HASH" \
            "$OWNER_ADDRESS" \
            "$TOKEN_ADDRESS" \
            "$MAX_BALANCE" \
            --network "$NETWORK" \
            --account "$ACCOUNT_FILE" \
            --keystore "$KEYSTORE" 2>&1 | tee /tmp/engine_deploy_output.txt
    else
        starkli deploy \
            "$CLASS_HASH" \
            "$OWNER_ADDRESS" \
            "$TOKEN_ADDRESS" \
            --network "$NETWORK" \
            --account "$ACCOUNT_FILE" \
            --keystore "$KEYSTORE" 2>&1 | tee /tmp/engine_deploy_output.txt
    fi
else
    if [ "$ENGINE_TYPE" = "rule" ]; then
        starkli deploy \
            "$CLASS_HASH" \
            "$OWNER_ADDRESS" \
            "$TOKEN_ADDRESS" \
            "$MAX_BALANCE" \
            --network "$NETWORK" \
            --account "$ACCOUNT" 2>&1 | tee /tmp/engine_deploy_output.txt
    else
        starkli deploy \
            "$CLASS_HASH" \
            "$OWNER_ADDRESS" \
            "$TOKEN_ADDRESS" \
            --network "$NETWORK" \
            --account "$ACCOUNT" 2>&1 | tee /tmp/engine_deploy_output.txt
    fi
fi

# Check for errors in the output
if grep -q "Error:" /tmp/engine_deploy_output.txt; then
    echo ""
    echo -e "${RED}Error: Deployment failed!${NC}"
    echo -e "${YELLOW}Output from deploy command:${NC}"
    cat /tmp/engine_deploy_output.txt
    echo ""
    exit 1
fi

# Extract contract address from output - compatible with macOS grep
CONTRACT_ADDRESS=$(grep "Contract deployed:" /tmp/engine_deploy_output.txt | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)

if [ -z "$CONTRACT_ADDRESS" ]; then
    CONTRACT_ADDRESS=$(grep "will be deployed at address" /tmp/engine_deploy_output.txt | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)
fi

if [ -z "$CONTRACT_ADDRESS" ]; then
    CONTRACT_ADDRESS=$(grep "contract_address" /tmp/engine_deploy_output.txt | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)
fi

if [ -z "$CONTRACT_ADDRESS" ]; then
    echo ""
    echo -e "${YELLOW}Note: Could not extract contract address from output.${NC}"
    echo -e "${YELLOW}Output from deploy command:${NC}"
    cat /tmp/engine_deploy_output.txt
    echo ""
    read -p "Please enter the contract address manually (or press Ctrl+C to exit): " CONTRACT_ADDRESS
    if [ -z "$CONTRACT_ADDRESS" ]; then
        echo -e "${RED}Error: Contract address is required${NC}"
        exit 1
    fi
fi

# Extract transaction hash if available
TX_HASH=$(grep "transaction_hash" /tmp/engine_deploy_output.txt | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)
if [ -z "$TX_HASH" ]; then
    TX_HASH=$(grep "Transaction hash:" /tmp/engine_deploy_output.txt | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)
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
echo -e "${YELLOW}Engine Type:${NC} $ENGINE_TYPE"
echo -e "${YELLOW}Engine Address:${NC} $CONTRACT_ADDRESS"
echo -e "${YELLOW}Class Hash:${NC} $CLASS_HASH"
if [ -n "$TX_HASH" ]; then
    echo -e "${YELLOW}Transaction Hash:${NC} $TX_HASH"
fi
echo ""
echo -e "${GREEN}Block Explorer URLs:${NC}"
echo -e "${BLUE}Contract: $EXPLORER_URL/contract/$CONTRACT_ADDRESS${NC}"
if [ -n "$TX_HASH" ]; then
    echo -e "${BLUE}Transaction: $EXPLORER_URL/tx/$TX_HASH${NC}"
fi
echo ""
echo -e "${BLUE}================================================${NC}"

# Save deployment info
DEPLOYMENT_FILE="deployments/engine_${ENGINE_TYPE}_${NETWORK}_$(date +%Y%m%d_%H%M%S).json"
mkdir -p deployments

cat > "$DEPLOYMENT_FILE" << EOF
{
  "engine_type": "$ENGINE_TYPE",
  "network": "$NETWORK",
  "contract_address": "$CONTRACT_ADDRESS",
  "class_hash": "$CLASS_HASH",
  "transaction_hash": "${TX_HASH:-N/A}",
  "token_address": "$TOKEN_ADDRESS",
  "owner": "$OWNER_ADDRESS",
  "max_balance": "$MAX_BALANCE",
  "explorer_url": "$EXPLORER_URL/contract/$CONTRACT_ADDRESS",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo -e "${GREEN}Deployment details saved to: $DEPLOYMENT_FILE${NC}"
echo ""

# Display next steps based on engine type
if [ "$ENGINE_TYPE" = "rule" ]; then
    echo -e "${YELLOW}Next Steps for Rule Engine:${NC}"
    echo "1. Add addresses to whitelist"
    echo "2. Configure the token contract to use this rule engine"
    echo "3. Test transfer restrictions"
    echo ""
    echo -e "${YELLOW}Example commands:${NC}"
    echo "  # Add address to whitelist"
    echo "  starkli invoke $CONTRACT_ADDRESS add_to_whitelist <address> --network $NETWORK --account $ACCOUNT"
    echo ""
    echo "  # Batch add addresses"
    echo "  starkli invoke $CONTRACT_ADDRESS batch_add_to_whitelist \"[<addr1>,<addr2>]\" --network $NETWORK --account $ACCOUNT"
    echo ""
    echo "  # Check if address is valid"
    echo "  starkli call $CONTRACT_ADDRESS is_address_valid <address> --network $NETWORK"
    echo ""
    echo "  # Detect transfer restriction"
    echo "  starkli call $CONTRACT_ADDRESS detect_transfer_restriction <from> <to> <amount> --network $NETWORK"
else
    echo -e "${YELLOW}Next Steps for Snapshot Engine:${NC}"
    echo "1. Schedule snapshots"
    echo "2. Configure the token contract to record snapshots"
    echo "3. Query historical balances"
    echo ""
    echo -e "${YELLOW}Example commands:${NC}"
    echo "  # Schedule a snapshot (timestamp)"
    echo "  starkli invoke $CONTRACT_ADDRESS schedule_snapshot <timestamp> --network $NETWORK --account $ACCOUNT"
    echo ""
    echo "  # Get snapshot info"
    echo "  starkli call $CONTRACT_ADDRESS get_snapshot <snapshot_id> --network $NETWORK"
    echo ""
    echo "  # Query balance at snapshot"
    echo "  starkli call $CONTRACT_ADDRESS balance_of_at <account> <snapshot_id> --network $NETWORK"
    echo ""
    echo "  # Batch query balances"
    echo "  starkli call $CONTRACT_ADDRESS batch_balance_of_at \"[<addr1>,<addr2>]\" <snapshot_id> --network $NETWORK"
fi

echo ""

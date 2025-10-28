#!/bin/bash
# SPDX-License-Identifier: MPL-2.0
# Deployment script for CMTAT tokens on Starknet

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NETWORK="${NETWORK:-sepolia}"
ACCOUNT="${ACCOUNT:-default}"
ACCOUNT_FILE="${ACCOUNT_FILE:-$HOME/.starknet-accounts/account.json}"
KEYSTORE="${KEYSTORE:-$HOME/.starknet-wallets/keystore.json}"

# Default parameters
DEFAULT_INITIAL_SUPPLY="1000000000000000000000000" # 1,000,000 tokens with 18 decimals
DEFAULT_TERMS="0x54657374546f6b656e" # "TestToken" in hex
DEFAULT_FLAG="0x1"
DEFAULT_TYPE="working" # Default contract type

# Debt-specific defaults
DEFAULT_ISIN="US12345678" # Sample ISIN
DEFAULT_MATURITY_DATE="1735689600" # Jan 1, 2025 timestamp
DEFAULT_INTEREST_RATE="500" # 5% (500 basis points)
DEFAULT_PAR_VALUE="1000000000000000000000" # 1000 tokens (18 decimals)

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  CMTAT Token Deployment Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --network NETWORK       Starknet network (default: sepolia)"
    echo "  --account ACCOUNT       Account name (default: default)"
    echo "  --account-file FILE     Account config file (default: ~/.starknet-accounts/account.json)"
    echo "  --keystore FILE         Keystore file (default: ~/.starknet-wallets/keystore.json)"
    echo "  --admin ADDRESS         Admin address (required if not provided interactively)"
    echo "  --recipient ADDRESS     Initial token recipient (required if not provided interactively)"
    echo "  --supply AMOUNT         Initial supply (default: $DEFAULT_INITIAL_SUPPLY)"
    echo "  --name NAME             Token name (default: CMTAT Token)"
    echo "  --symbol SYMBOL         Token symbol (default: CMTAT)"
    echo "  --terms TERMS           Terms felt252 (default: $DEFAULT_TERMS)"
    echo "  --flag FLAG             Flag felt252 (default: $DEFAULT_FLAG)"
    echo "  --type TYPE             Contract type: working, standard, light, debt (default: working)"
    echo "  --isin ISIN             ISIN for debt instruments (default: $DEFAULT_ISIN)"
    echo "  --maturity-date DATE    Maturity date timestamp for debt (default: $DEFAULT_MATURITY_DATE)"
    echo "  --interest-rate RATE    Interest rate in basis points for debt (default: $DEFAULT_INTEREST_RATE)"
    echo "  --par-value VALUE       Par value for debt instruments (default: $DEFAULT_PAR_VALUE)"
    echo "  --help                  Display this help message"
    echo ""
    echo "Examples:"
    echo "  Deploy standard CMTAT:"
    echo "    $0 --network sepolia --name \"My Token\" --symbol \"MTK\""
    echo ""
    echo "  Deploy with custom parameters:"
    echo "    $0 --admin 0x123... --supply 10000000 --network mainnet"
    exit 1
}

# Parse command line arguments
ADMIN=""
RECIPIENT=""
SUPPLY="$DEFAULT_INITIAL_SUPPLY"
NAME="CMTAT Token"
SYMBOL="CMTAT"
TERMS="$DEFAULT_TERMS"
FLAG="$DEFAULT_FLAG"
CONTRACT_TYPE="$DEFAULT_TYPE"

# Debt-specific variables
ISIN="$DEFAULT_ISIN"
MATURITY_DATE="$DEFAULT_MATURITY_DATE"
INTEREST_RATE="$DEFAULT_INTEREST_RATE"
PAR_VALUE="$DEFAULT_PAR_VALUE"

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
        --admin)
            ADMIN="$2"
            shift 2
            ;;
        --recipient)
            RECIPIENT="$2"
            shift 2
            ;;
        --supply)
            SUPPLY="$2"
            shift 2
            ;;
        --name)
            NAME="$2"
            shift 2
            ;;
        --symbol)
            SYMBOL="$2"
            shift 2
            ;;
        --terms)
            TERMS="$2"
            shift 2
            ;;
        --flag)
            FLAG="$2"
            shift 2
            ;;
        --type)
            CONTRACT_TYPE="$2"
            shift 2
            ;;
        --isin)
            ISIN="$2"
            shift 2
            ;;
        --maturity-date)
            MATURITY_DATE="$2"
            shift 2
            ;;
        --interest-rate)
            INTEREST_RATE="$2"
            shift 2
            ;;
        --par-value)
            PAR_VALUE="$2"
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

# Prompt for admin address if not provided
if [ -z "$ADMIN" ]; then
    echo -e "${YELLOW}Admin address is required for role management${NC}"
    read -p "Enter admin address: " ADMIN
    if [ -z "$ADMIN" ]; then
        echo -e "${RED}Error: Admin address is required${NC}"
        exit 1
    fi
fi

# Prompt for recipient address if not provided
if [ -z "$RECIPIENT" ]; then
    echo -e "${YELLOW}Recipient address will receive the initial token supply${NC}"
    read -p "Enter recipient address (or press Enter to use admin address): " RECIPIENT
    if [ -z "$RECIPIENT" ]; then
        RECIPIENT="$ADMIN"
        echo -e "${GREEN}Using admin address as recipient${NC}"
    fi
fi

# Set explorer URL based on network
if [ "$NETWORK" = "mainnet" ]; then
    EXPLORER_URL="https://voyager.online"
else
    EXPLORER_URL="https://sepolia.voyager.online"
fi

echo ""
echo -e "${YELLOW}Deployment Configuration:${NC}"
echo "  Network: $NETWORK"
echo "  Account: $ACCOUNT"
echo "  Admin: $ADMIN"
echo "  Recipient: $RECIPIENT"
echo "  Initial Supply: $SUPPLY"
echo "  Token Name: $NAME"
echo "  Token Symbol: $SYMBOL"
echo "  Terms: $TERMS"
echo "  Flag: $FLAG"
echo "  Contract Type: $CONTRACT_TYPE"

# Show debt-specific parameters if deploying debt contract
if [ "$CONTRACT_TYPE" = "debt" ]; then
    echo "  ISIN: $ISIN"
    echo "  Maturity Date: $MATURITY_DATE"
    echo "  Interest Rate: $INTEREST_RATE"
    echo "  Par Value: $PAR_VALUE"
fi

echo ""

# Check if scarb is installed
if ! command -v scarb &> /dev/null; then
    echo -e "${RED}Error: scarb is not installed${NC}"
    echo "Please install scarb: https://docs.swmansion.com/scarb/"
    exit 1
fi

# Check if starkli is installed
if ! command -v starkli &> /dev/null; then
    echo -e "${RED}Error: starkli is not installed${NC}"
    echo "Please install starkli: https://book.starkli.rs/installation"
    exit 1
fi

# Build the project
echo -e "${BLUE}Step 1: Building the contract...${NC}"
scarb build

if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Contract built successfully${NC}"
echo ""

# Determine contract file based on type
case "$CONTRACT_TYPE" in
    working)
        CONTRACT_FILE="cairo_cmtat_CMTAT_ERC20.contract_class.json"
        CONTRACT_NAME="CMTAT_ERC20"
        ;;
    standard)
        CONTRACT_FILE="cairo_cmtat_StandardCMTAT.contract_class.json"
        CONTRACT_NAME="StandardCMTAT"
        ;;
    light)
        CONTRACT_FILE="cairo_cmtat_LightCMTAT.contract_class.json"
        CONTRACT_NAME="LightCMTAT"
        ;;
    debt)
        CONTRACT_FILE="cairo_cmtat_SimpleFeltDebtCMTAT.contract_class.json"
        CONTRACT_NAME="SimpleFeltDebtCMTAT"
        ;;
    *)
        echo -e "${RED}Invalid contract type: $CONTRACT_TYPE${NC}"
        echo "Valid types: working, standard, light, debt"
        exit 1
        ;;
esac

# Deploy the contract
echo -e "${BLUE}Step 2: Declaring the contract class...${NC}"

# Declare the contract and save output
if [ -f "$ACCOUNT_FILE" ] && [ -f "$KEYSTORE" ]; then
    starkli declare \
        target/dev/$CONTRACT_FILE \
        --network "$NETWORK" \
        --account "$ACCOUNT_FILE" \
        --keystore "$KEYSTORE" 2>&1 | tee /tmp/cmtat_declare_output.txt
else
    starkli declare \
        target/dev/$CONTRACT_FILE \
        --network "$NETWORK" \
        --account "$ACCOUNT" 2>&1 | tee /tmp/cmtat_declare_output.txt
fi

# Check for errors in declare output
if grep -q "Error:" /tmp/cmtat_declare_output.txt || grep -q "exceed balance" /tmp/cmtat_declare_output.txt; then
    echo ""
    echo -e "${RED}Error: Declaration failed!${NC}"
    echo -e "${YELLOW}Output from declare command:${NC}"
    cat /tmp/cmtat_declare_output.txt
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
    # Try "Class hash declared:" first
    CLASS_HASH=$(grep "Class hash declared:" /tmp/cmtat_declare_output.txt | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)

    # Try "already declared. Class hash:"
    if [ -z "$CLASS_HASH" ]; then
        CLASS_HASH=$(grep "already declared. Class hash:" /tmp/cmtat_declare_output.txt | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)
    fi

    # Try standalone "Class hash:"
    if [ -z "$CLASS_HASH" ]; then
        CLASS_HASH=$(grep "Class hash:" /tmp/cmtat_declare_output.txt | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)
    fi

    # Try "Declaring Cairo 1 class:"
    if [ -z "$CLASS_HASH" ]; then
        CLASS_HASH=$(grep "Declaring Cairo 1 class:" /tmp/cmtat_declare_output.txt | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)
    fi

    if [ -z "$CLASS_HASH" ]; then
        echo ""
        echo -e "${YELLOW}Note: Could not extract class hash from output.${NC}"
        echo -e "${YELLOW}Output from declare command:${NC}"
        cat /tmp/cmtat_declare_output.txt
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

# Helper function to convert string to felt252 (short string)
string_to_felt252() {
    local str="$1"
    # Convert string to hex (short string format)
    printf "%s" "$str" | xxd -p | sed 's/^/0x/'
}

# Deploy the contract
echo -e "${BLUE}Step 3: Deploying the contract...${NC}"

# Different deployment parameters based on contract type
if [ "$CONTRACT_TYPE" = "working" ]; then
    # CMTAT_ERC20 only takes recipient address
    if [ -f "$ACCOUNT_FILE" ] && [ -f "$KEYSTORE" ]; then
        starkli deploy \
            "$CLASS_HASH" \
            "$RECIPIENT" \
            --network "$NETWORK" \
            --account "$ACCOUNT_FILE" \
            --keystore "$KEYSTORE" 2>&1 | tee /tmp/cmtat_deploy_output.txt
    else
        starkli deploy \
            "$CLASS_HASH" \
            "$RECIPIENT" \
            --network "$NETWORK" \
            --account "$ACCOUNT" 2>&1 | tee /tmp/cmtat_deploy_output.txt
    fi
elif [ "$CONTRACT_TYPE" = "debt" ]; then
    # SimpleFeltDebtCMTAT takes felt252 parameters - use starkli's str: prefix for conversion
    echo -e "${YELLOW}Note: Using starkli's built-in string to felt252 conversion${NC}"
    echo ""
    
    if [ -f "$ACCOUNT_FILE" ] && [ -f "$KEYSTORE" ]; then
        starkli deploy \
            "$CLASS_HASH" \
            "$ADMIN" \
            "str:$NAME" \
            "str:$SYMBOL" \
            "u256:$SUPPLY" \
            "$RECIPIENT" \
            "$TERMS" \
            "$FLAG" \
            "str:$ISIN" \
            "u64:$MATURITY_DATE" \
            "u256:$INTEREST_RATE" \
            "u256:$PAR_VALUE" \
            --network "$NETWORK" \
            --account "$ACCOUNT_FILE" \
            --keystore "$KEYSTORE" 2>&1 | tee /tmp/cmtat_deploy_output.txt
    else
        starkli deploy \
            "$CLASS_HASH" \
            "$ADMIN" \
            "str:$NAME" \
            "str:$SYMBOL" \
            "u256:$SUPPLY" \
            "$RECIPIENT" \
            "$TERMS" \
            "$FLAG" \
            "str:$ISIN" \
            "u64:$MATURITY_DATE" \
            "u256:$INTEREST_RATE" \
            "u256:$PAR_VALUE" \
            --network "$NETWORK" \
            --account "$ACCOUNT" 2>&1 | tee /tmp/cmtat_deploy_output.txt
    fi
else
    # Other CMTAT contracts (standard, light) take standard parameters
    if [ -f "$ACCOUNT_FILE" ] && [ -f "$KEYSTORE" ]; then
        starkli deploy \
            "$CLASS_HASH" \
            "$ADMIN" \
            str:"$NAME" \
            str:"$SYMBOL" \
            u256:"$SUPPLY" \
            "$RECIPIENT" \
            "$TERMS" \
            "$FLAG" \
            --network "$NETWORK" \
            --account "$ACCOUNT_FILE" \
            --keystore "$KEYSTORE" 2>&1 | tee /tmp/cmtat_deploy_output.txt
    else
        starkli deploy \
            "$CLASS_HASH" \
            "$ADMIN" \
            str:"$NAME" \
            str:"$SYMBOL" \
            u256:"$SUPPLY" \
            "$RECIPIENT" \
            "$TERMS" \
            "$FLAG" \
            --network "$NETWORK" \
            --account "$ACCOUNT" 2>&1 | tee /tmp/cmtat_deploy_output.txt
    fi
fi

# Check for errors in the output
if grep -q "Error:" /tmp/cmtat_deploy_output.txt; then
    echo ""
    echo -e "${RED}Error: Deployment failed!${NC}"
    echo -e "${YELLOW}Output from deploy command:${NC}"
    cat /tmp/cmtat_deploy_output.txt
    echo ""
    exit 1
fi

# Extract contract address from output - compatible with macOS grep
# First try "Contract deployed:" message
CONTRACT_ADDRESS=$(grep "Contract deployed:" /tmp/cmtat_deploy_output.txt | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)

# If not found, try "will be deployed at address" message (predicted address)
if [ -z "$CONTRACT_ADDRESS" ]; then
    CONTRACT_ADDRESS=$(grep "will be deployed at address" /tmp/cmtat_deploy_output.txt | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)
fi

# If still not found, try to extract from transaction receipt
if [ -z "$CONTRACT_ADDRESS" ]; then
    CONTRACT_ADDRESS=$(grep "contract_address" /tmp/cmtat_deploy_output.txt | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)
fi

if [ -z "$CONTRACT_ADDRESS" ]; then
    echo ""
    echo -e "${YELLOW}Note: Could not extract contract address from output.${NC}"
    echo -e "${YELLOW}Output from deploy command:${NC}"
    cat /tmp/cmtat_deploy_output.txt
    echo ""
    read -p "Please enter the contract address manually (or press Ctrl+C to exit): " CONTRACT_ADDRESS
    if [ -z "$CONTRACT_ADDRESS" ]; then
        echo -e "${RED}Error: Contract address is required${NC}"
        exit 1
    fi
fi

# Extract transaction hash if available
TX_HASH=$(grep "transaction_hash" /tmp/cmtat_deploy_output.txt | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)
if [ -z "$TX_HASH" ]; then
    TX_HASH=$(grep "Transaction hash:" /tmp/cmtat_deploy_output.txt | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)
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
echo -e "${YELLOW}Contract Type:${NC} $CONTRACT_NAME"
echo -e "${YELLOW}Contract Address:${NC} $CONTRACT_ADDRESS"
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
DEPLOYMENT_FILE="deployments/${CONTRACT_NAME}_${NETWORK}_$(date +%Y%m%d_%H%M%S).json"
mkdir -p deployments

cat > "$DEPLOYMENT_FILE" << EOF
{
  "network": "$NETWORK",
  "contract_type": "$CONTRACT_NAME",
  "contract_address": "$CONTRACT_ADDRESS",
  "class_hash": "$CLASS_HASH",
  "transaction_hash": "${TX_HASH:-N/A}",
  "admin": "$ADMIN",
  "recipient": "$RECIPIENT",
  "initial_supply": "$SUPPLY",
  "token_name": "$NAME",
  "token_symbol": "$SYMBOL",
  "terms": "$TERMS",
  "flag": "$FLAG",
  "explorer_url": "$EXPLORER_URL/contract/$CONTRACT_ADDRESS",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo -e "${GREEN}Deployment details saved to: $DEPLOYMENT_FILE${NC}"
echo ""

# Display next steps
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Verify the contract on the block explorer"
echo "2. Test token functionality (mint, transfer, freeze)"
echo "3. Grant additional roles if needed"
echo ""
echo -e "${YELLOW}Example commands:${NC}"
echo "  # Check balance"
echo "  starkli call $CONTRACT_ADDRESS balance_of $RECIPIENT --network $NETWORK"
echo ""
echo "  # Mint tokens (requires MINTER_ROLE)"
echo "  starkli invoke $CONTRACT_ADDRESS mint <recipient> <amount> --network $NETWORK --account $ACCOUNT"
echo ""
echo "  # Freeze address (requires ENFORCER_ROLE)"
echo "  starkli invoke $CONTRACT_ADDRESS freeze_address <address> --network $NETWORK --account $ACCOUNT"
echo ""

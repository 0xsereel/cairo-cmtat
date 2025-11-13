#!/bin/bash

# CMTAT Factory Deployment Script
# This script deploys the complete CMTAT Factory ecosystem on Starknet

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== CMTAT Factory Deployment Script ===${NC}"
echo ""

# Source environment variables
if [ ! -f ".env" ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Please create a .env file with your Alchemy API key"
    exit 1
fi

source .env

# Validate required environment variables
if [ -z "$ALCHEMY_API_KEY" ] || [ "$ALCHEMY_API_KEY" == "your_alchemy_api_key_here" ]; then
    echo -e "${RED}Error: ALCHEMY_API_KEY not set in .env file${NC}"
    echo "Please set your Alchemy API key in .env"
    exit 1
fi

# Construct RPC URL
RPC_URL="${STARKNET_RPC_URL}/${ALCHEMY_API_KEY}"

echo -e "${GREEN}✓ Environment variables loaded${NC}"
echo -e "Network: ${STARKNET_NETWORK}"
echo -e "Account: ${STARKNET_ACCOUNT}"
echo ""

# Build contracts
echo -e "${BLUE}=== Building Contracts ===${NC}"
scarb build
echo -e "${GREEN}✓ Build complete${NC}"
echo ""

# Function to declare a contract and extract class hash
declare_contract() {
    local contract_name=$1
    local var_name=$2
    
    echo -e "${BLUE}=== Declaring ${contract_name} ===${NC}"
    
    local output=$(sncast declare --contract-name $contract_name \
        --url "$RPC_URL" 2>&1)
    
    if echo "$output" | grep -q "error\|Error"; then
        echo -e "${YELLOW}Warning: $contract_name may already be declared${NC}"
        echo "$output"
        # Try to extract class hash from error message if it's already declared
        local class_hash=$(echo "$output" | grep -o "0x[a-fA-F0-9]\{64\}" | head -n1)
        if [ ! -z "$class_hash" ]; then
            echo -e "${GREEN}✓ Using existing class hash: $class_hash${NC}"
            eval "$var_name=$class_hash"
        else
            echo -e "${RED}✗ Failed to declare $contract_name${NC}"
            return 1
        fi
    else
        # Extract class hash from successful declaration
        local class_hash=$(echo "$output" | grep "Class hash declared:" | grep -o "0x[a-fA-F0-9]\{64\}")
        if [ ! -z "$class_hash" ]; then
            echo -e "${GREEN}✓ Class hash: $class_hash${NC}"
            eval "$var_name=$class_hash"
        else
            echo -e "${RED}✗ Failed to extract class hash for $contract_name${NC}"
            return 1
        fi
    fi
    echo ""
}

# Declare all CMTAT implementations
declare_contract "StandardCMTAT" "STANDARD_CLASS_HASH"
declare_contract "DebtCMTAT" "DEBT_CLASS_HASH"  
declare_contract "LightCMTAT" "LIGHT_CLASS_HASH"

# Declare the Factory contract
declare_contract "CMTATFactory" "FACTORY_CLASS_HASH"

# Deploy the Factory
echo -e "${BLUE}=== Deploying CMTAT Factory ===${NC}"
echo "Constructor parameters:"
echo "  Owner: $ADMIN_ADDRESS"
echo "  Standard Class Hash: $STANDARD_CLASS_HASH"
echo "  Debt Class Hash: $DEBT_CLASS_HASH"
echo "  Light Class Hash: $LIGHT_CLASS_HASH"
echo ""

FACTORY_OUTPUT=$(sncast deploy \
    --class-hash "$FACTORY_CLASS_HASH" \
    --constructor-calldata "$ADMIN_ADDRESS" "$STANDARD_CLASS_HASH" "$DEBT_CLASS_HASH" "$LIGHT_CLASS_HASH" \
    --url "$RPC_URL" 2>&1)

if echo "$FACTORY_OUTPUT" | grep -q "error\|Error"; then
    echo -e "${RED}✗ Failed to deploy Factory${NC}"
    echo "$FACTORY_OUTPUT"
    exit 1
else
    FACTORY_ADDRESS=$(echo "$FACTORY_OUTPUT" | grep "Contract address:" | grep -o "0x[a-fA-F0-9]\{64\}")
    if [ ! -z "$FACTORY_ADDRESS" ]; then
        echo -e "${GREEN}✓ Factory deployed at: $FACTORY_ADDRESS${NC}"
    else
        echo -e "${RED}✗ Failed to extract factory address${NC}"
        exit 1
    fi
fi

echo ""

# Update .env file with deployment results
echo -e "${BLUE}=== Updating .env file ===${NC}"
cat > .env.tmp << EOF
# Starknet Configuration
ALCHEMY_API_KEY=$ALCHEMY_API_KEY

# Network Configuration
STARKNET_NETWORK=$STARKNET_NETWORK
STARKNET_RPC_URL=$STARKNET_RPC_URL

# Account Configuration
STARKNET_ACCOUNT=$STARKNET_ACCOUNT
ACCOUNTS_FILE=$ACCOUNTS_FILE
KEYSTORE_FILE=$KEYSTORE_FILE

# Deployment Configuration
ADMIN_ADDRESS=$ADMIN_ADDRESS

# Factory Deployment Results
STANDARD_CMTAT_CLASS_HASH=$STANDARD_CLASS_HASH
DEBT_CMTAT_CLASS_HASH=$DEBT_CLASS_HASH
LIGHT_CMTAT_CLASS_HASH=$LIGHT_CLASS_HASH
FACTORY_CLASS_HASH=$FACTORY_CLASS_HASH
FACTORY_ADDRESS=$FACTORY_ADDRESS
EOF

mv .env.tmp .env
echo -e "${GREEN}✓ .env file updated with deployment results${NC}"

echo ""
echo -e "${GREEN}🎉 CMTAT Factory Deployment Complete!${NC}"
echo ""
echo -e "${BLUE}=== Deployment Summary ===${NC}"
echo -e "Factory Address:        ${FACTORY_ADDRESS}"
echo -e "Standard CMTAT Class:   ${STANDARD_CLASS_HASH}"
echo -e "Debt CMTAT Class:       ${DEBT_CLASS_HASH}"
echo -e "Light CMTAT Class:      ${LIGHT_CLASS_HASH}"
echo -e "Factory Class:          ${FACTORY_CLASS_HASH}"
echo ""
echo -e "${BLUE}🔗 Starkscan Links:${NC}"
echo -e "Factory: https://sepolia.starkscan.co/contract/${FACTORY_ADDRESS}"
echo ""
echo -e "${BLUE}📋 Next Steps:${NC}"
echo "1. Test Standard CMTAT deployment via factory"
echo "2. Test Debt CMTAT deployment via factory"  
echo "3. Test Light CMTAT deployment via factory"
echo "4. Verify deployment tracking functions"
echo ""
echo -e "${GREEN}Ready for testing! Run: ./scripts/test_factory.sh${NC}"
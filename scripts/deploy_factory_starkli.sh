#!/bin/bash

# CMTAT Factory Deployment - Simple Version
# Using known class hashes and manual factory deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== CMTAT Factory Deployment - Simple ===${NC}"
echo ""

# Source environment variables
source .env

# Use known working class hashes
STANDARD_CLASS_HASH="0x0156438638cbac97e09e5781c66d4e23092d43b85c94286d11578f6b604a6463"
DEBT_CLASS_HASH="0x073df1d757f9927b737ae61d1b350aeefa4df2bf1cfc73c47c017b9e80e246e7"
LIGHT_CLASS_HASH="0x0040ce9334f9146f53e6e32c7b8fe9644cc5d6cece7507768cdbfecbf57b27f1"

# The funded account address
ACCOUNT_ADDRESS="0x02cd00393b1507e96b93e5c4e10064b71fbb7786c98fdebab62d20d5a37db0b3"

echo -e "${GREEN}✓ Using pre-declared CMTAT implementations:${NC}"
echo -e "  Standard CMTAT: ${STANDARD_CLASS_HASH}"
echo -e "  Debt CMTAT:     ${DEBT_CLASS_HASH}"
echo -e "  Light CMTAT:    ${LIGHT_CLASS_HASH}"
echo -e "  Account:        ${ACCOUNT_ADDRESS}"
echo ""

# Build contracts
echo -e "${BLUE}=== Building Contracts ===${NC}"
scarb build
echo -e "${GREEN}✓ Build complete${NC}"
echo ""

# For the factory, since we need to declare it, let me try using starkli directly
echo -e "${BLUE}=== Declaring CMTATFactory with starkli ===${NC}"

# Run starkli declare and capture both output and exit code
FACTORY_OUTPUT=$(starkli declare target/dev/cairo_cmtat_CMTATFactory.contract_class.json \
    --keystore ./local_keystore.json \
    --account "$ACCOUNT_ADDRESS" \
    --rpc "https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_7/${ALCHEMY_API_KEY}" 2>&1)
DECLARE_EXIT=$?

echo "Declaration output:"
echo "$FACTORY_OUTPUT"

# Check exit code first - only proceed on success
if [ $DECLARE_EXIT -ne 0 ]; then
    echo -e "${RED}✗ Factory declaration command failed with exit code $DECLARE_EXIT${NC}"
    echo "$FACTORY_OUTPUT"
    exit 1
fi

# On success, parse class hash from explicit success patterns only
if echo "$FACTORY_OUTPUT" | grep -q "Class hash declared:"; then
    # Extract from "Class hash declared:" line (4th token)
    FACTORY_CLASS_HASH=$(echo "$FACTORY_OUTPUT" | grep "Class hash declared:" | awk '{print $4}')
    if [ -z "$FACTORY_CLASS_HASH" ]; then
        echo -e "${RED}✗ Failed to extract class hash from 'Class hash declared:' line${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Factory class hash declared: $FACTORY_CLASS_HASH${NC}"
elif echo "$FACTORY_OUTPUT" | grep -q "already declared"; then
    # Handle "already declared" case - parse known format
    FACTORY_CLASS_HASH=$(echo "$FACTORY_OUTPUT" | grep "already declared" | grep -o "0x[a-fA-F0-9]\{64\}" | head -n1)
    if [ -z "$FACTORY_CLASS_HASH" ]; then
        echo -e "${RED}✗ Failed to extract class hash from 'already declared' message${NC}"
        exit 1
    fi
    echo -e "${YELLOW}✓ Factory already declared with class hash: $FACTORY_CLASS_HASH${NC}"
else
    echo -e "${RED}✗ Unexpected declaration output format - neither 'Class hash declared:' nor 'already declared' found${NC}"
    echo "Expected either:"
    echo "  - 'Class hash declared: 0x...'"
    echo "  - '... already declared ...'"
    exit 1
fi

echo ""

# Deploy the Factory
echo -e "${BLUE}=== Deploying CMTAT Factory ===${NC}"
echo "Constructor parameters:"
echo "  Owner: $ACCOUNT_ADDRESS"
echo "  Standard Class Hash: $STANDARD_CLASS_HASH"
echo "  Debt Class Hash: $DEBT_CLASS_HASH"
echo "  Light Class Hash: $LIGHT_CLASS_HASH"
echo ""

# Run starkli deploy and capture both output and exit code
DEPLOY_OUTPUT=$(starkli deploy \
    "$FACTORY_CLASS_HASH" \
    "$ACCOUNT_ADDRESS" "$STANDARD_CLASS_HASH" "$DEBT_CLASS_HASH" "$LIGHT_CLASS_HASH" \
    --keystore ./local_keystore.json \
    --account "$ACCOUNT_ADDRESS" \
    --rpc "https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_7/${ALCHEMY_API_KEY}" 2>&1)
DEPLOY_EXIT=$?

echo "Deployment output:"
echo "$DEPLOY_OUTPUT"

# Check exit code first - only proceed on success
if [ $DEPLOY_EXIT -ne 0 ]; then
    echo -e "${RED}✗ Factory deployment command failed with exit code $DEPLOY_EXIT${NC}"
    echo "$DEPLOY_OUTPUT"
    exit 1
fi

# On success, parse contract address from explicit success pattern only
if echo "$DEPLOY_OUTPUT" | grep -q "Contract deployed:"; then
    # Extract from "Contract deployed:" line (3rd token)
    FACTORY_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "Contract deployed:" | awk '{print $3}')
    if [ -z "$FACTORY_ADDRESS" ]; then
        echo -e "${RED}✗ Failed to extract contract address from 'Contract deployed:' line${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Factory deployed at: $FACTORY_ADDRESS${NC}"
else
    echo -e "${RED}✗ Unexpected deployment output format - 'Contract deployed:' not found${NC}"
    echo "Expected: 'Contract deployed: 0x...'"
    exit 1
fi

echo ""

# Update .env file with deployment results
echo -e "${BLUE}=== Updating .env file ===${NC}"
cat > .env << EOF
# Starknet Configuration
ALCHEMY_API_KEY=$ALCHEMY_API_KEY

# Network Configuration
STARKNET_NETWORK=sepolia
STARKNET_RPC_URL=https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_7

# Account Configuration
STARKNET_ACCOUNT=factory_account
ACCOUNTS_FILE=./local_keystore.json
KEYSTORE_FILE=./local_keystore.json

# Deployment Configuration
ADMIN_ADDRESS=$ACCOUNT_ADDRESS

# Factory Deployment Results
STANDARD_CMTAT_CLASS_HASH=$STANDARD_CLASS_HASH
DEBT_CMTAT_CLASS_HASH=$DEBT_CLASS_HASH
LIGHT_CMTAT_CLASS_HASH=$LIGHT_CLASS_HASH
FACTORY_CLASS_HASH=$FACTORY_CLASS_HASH
FACTORY_ADDRESS=$FACTORY_ADDRESS
EOF

echo -e "${GREEN}✓ .env file updated${NC}"

echo ""
echo -e "${GREEN}🎉 CMTAT Factory Deployment Complete!${NC}"
echo ""
echo -e "${BLUE}=== Final Deployment Summary ===${NC}"
echo -e "Factory Address:        ${FACTORY_ADDRESS}"
echo -e "Standard CMTAT Class:   ${STANDARD_CLASS_HASH}"
echo -e "Debt CMTAT Class:       ${DEBT_CLASS_HASH}"
echo -e "Light CMTAT Class:      ${LIGHT_CLASS_HASH}"
echo -e "Factory Class:          ${FACTORY_CLASS_HASH}"
echo -e "Admin/Owner:            ${ACCOUNT_ADDRESS}"
echo ""
echo -e "${BLUE}🔗 Starkscan Links:${NC}"
echo -e "Factory: https://sepolia.starkscan.co/contract/${FACTORY_ADDRESS}"
echo -e "Account: https://sepolia.starkscan.co/contract/${ACCOUNT_ADDRESS}"
echo ""
echo -e "${GREEN}✅ SUCCESS! The CMTAT Factory is now deployed!${NC}"
echo ""
echo "The factory can now deploy CMTAT tokens using the three implementations."
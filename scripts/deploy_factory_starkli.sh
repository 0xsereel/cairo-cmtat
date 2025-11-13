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

FACTORY_OUTPUT=$(starkli declare target/dev/cairo_cmtat_CMTATFactory.contract_class.json \
    --keystore ./local_keystore.json \
    --account "$ACCOUNT_ADDRESS" \
    --rpc "https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_7/${ALCHEMY_API_KEY}" 2>&1)

echo "Declaration output:"
echo "$FACTORY_OUTPUT"

if echo "$FACTORY_OUTPUT" | grep -q "Class hash declared:"; then
    FACTORY_CLASS_HASH=$(echo "$FACTORY_OUTPUT" | grep "Class hash declared:" | awk '{print $4}')
    echo -e "${GREEN}✓ Factory class hash: $FACTORY_CLASS_HASH${NC}"
elif echo "$FACTORY_OUTPUT" | grep -q "0x"; then
    # Try to extract any class hash from the output
    FACTORY_CLASS_HASH=$(echo "$FACTORY_OUTPUT" | grep -o "0x[a-fA-F0-9]\{64\}" | head -n1)
    if [ ! -z "$FACTORY_CLASS_HASH" ]; then
        echo -e "${YELLOW}Using class hash from output: $FACTORY_CLASS_HASH${NC}"
    else
        echo -e "${RED}✗ Could not extract factory class hash${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Factory declaration failed${NC}"
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

DEPLOY_OUTPUT=$(starkli deploy \
    "$FACTORY_CLASS_HASH" \
    "$ACCOUNT_ADDRESS" "$STANDARD_CLASS_HASH" "$DEBT_CLASS_HASH" "$LIGHT_CLASS_HASH" \
    --keystore ./local_keystore.json \
    --account "$ACCOUNT_ADDRESS" \
    --rpc "https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_7/${ALCHEMY_API_KEY}")

echo "Deployment output:"
echo "$DEPLOY_OUTPUT"

if echo "$DEPLOY_OUTPUT" | grep -q "Contract deployed:"; then
    FACTORY_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "Contract deployed:" | awk '{print $3}')
    echo -e "${GREEN}✓ Factory deployed at: $FACTORY_ADDRESS${NC}"
else
    echo -e "${RED}✗ Factory deployment failed${NC}"
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
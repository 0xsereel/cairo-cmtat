#!/bin/bash

# CMTAT Factory Testing Script
# This script tests all deployment functions of the CMTAT Factory

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== CMTAT Factory Testing Script ===${NC}"
echo ""

# Source environment variables
if [ ! -f ".env" ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Please run ./scripts/deploy_factory.sh first to deploy the factory"
    echo "  ./scripts/deploy_factory.sh sncast    # Deploy with sncast (recommended)"
    echo "  ./scripts/deploy_factory.sh starkli   # Deploy with starkli (simple)"
    exit 1
fi

source .env

# Validate required environment variables
if [ -z "$FACTORY_ADDRESS" ]; then
    echo -e "${RED}Error: FACTORY_ADDRESS not set${NC}"
    echo "Please run ./scripts/deploy_factory.sh first to deploy the factory"
    echo "  ./scripts/deploy_factory.sh sncast    # Deploy with sncast (recommended)"
    echo "  ./scripts/deploy_factory.sh starkli   # Deploy with starkli (simple)"
    exit 1
fi

# Construct RPC URL
RPC_URL="${STARKNET_RPC_URL}/${ALCHEMY_API_KEY}"

echo -e "${GREEN}✓ Using Factory at: $FACTORY_ADDRESS${NC}"
echo ""

# Function to invoke factory methods
invoke_factory() {
    local function_name=$1
    shift
    local calldata="$@"
    
    echo -e "${BLUE}=== Invoking $function_name ===${NC}"
    echo "Calldata: $calldata"
    
    local output=$(sncast invoke \
        --contract-address "$FACTORY_ADDRESS" \
        --function "$function_name" \
        --calldata $calldata \
        --url "$RPC_URL" 2>&1)
    
    if echo "$output" | grep -q "error\|Error"; then
        echo -e "${RED}✗ Failed to invoke $function_name${NC}"
        echo "$output"
        return 1
    else
        local tx_hash=$(echo "$output" | grep "Transaction hash:" | grep -o "0x[a-fA-F0-9]\{64\}")
        if [ ! -z "$tx_hash" ]; then
            echo -e "${GREEN}✓ Transaction hash: $tx_hash${NC}"
            return 0
        else
            echo -e "${YELLOW}? Invocation completed but no transaction hash found${NC}"
            echo "$output"
            return 0
        fi
    fi
}

# Function to call (read-only) factory methods
call_factory() {
    local function_name=$1
    shift
    local calldata="$@"
    
    echo -e "${BLUE}=== Calling $function_name ===${NC}"
    if [ ! -z "$calldata" ]; then
        echo "Calldata: $calldata"
    fi
    
    local output=$(sncast call \
        --contract-address "$FACTORY_ADDRESS" \
        --function "$function_name" \
        $([ ! -z "$calldata" ] && echo "--calldata $calldata") \
        --url "$RPC_URL" 2>&1)
    
    if echo "$output" | grep -q "error\|Error"; then
        echo -e "${RED}✗ Failed to call $function_name${NC}"
        echo "$output"
        return 1
    else
        echo -e "${GREEN}✓ Result: $output${NC}"
        return 0
    fi
}

# Test 1: Query factory configuration
echo -e "${BLUE}=== Test 1: Query Factory Configuration ===${NC}"
call_factory "get_standard_class_hash"
call_factory "get_debt_class_hash"
call_factory "get_light_class_hash"
call_factory "get_deployment_count"
echo ""

# Test 2: Deploy Standard CMTAT
echo -e "${BLUE}=== Test 2: Deploy Standard CMTAT ===${NC}"
# Parameters: admin, name, symbol, initial_supply, recipient, terms, information, salt
SALT_STANDARD=$RANDOM
invoke_factory "deploy_standard_cmtat" \
    "$ADMIN_ADDRESS" \
    "0" "0x5374616e6461726420546573742054,6f6b656e" "19" \
    "0" "0x535454" "3" \
    "1000000" \
    "$ADMIN_ADDRESS" \
    "'ipfs://test-terms'" \
    "0" "0x546573742072756e" "8" \
    "$SALT_STANDARD"
echo ""

# Test 3: Deploy Light CMTAT  
echo -e "${BLUE}=== Test 3: Deploy Light CMTAT ===${NC}"
# Parameters: admin, name, symbol, initial_supply, recipient, terms, salt
SALT_LIGHT=$RANDOM
invoke_factory "deploy_light_cmtat" \
    "$ADMIN_ADDRESS" \
    "0" "0x4c6967687420546573742054,6f6b656e" "17" \
    "0" "0x4c5454" "3" \
    "500000" \
    "$ADMIN_ADDRESS" \
    "'ipfs://light-terms'" \
    "$SALT_LIGHT"
echo ""

# Test 4: Deploy Debt CMTAT
echo -e "${BLUE}=== Test 4: Deploy Debt CMTAT ===${NC}"
# Parameters: admin, name, symbol, initial_supply, recipient, terms, isin, maturity_date, interest_rate, par_value, rule_engine, snapshot_engine, salt
MATURITY_DATE=$(date -d "2026-01-01" +%s)
SALT_DEBT=$RANDOM
invoke_factory "deploy_debt_cmtat" \
    "$ADMIN_ADDRESS" \
    "0" "0x44656274205465737420546f,6b656e" "15" \
    "0" "0x445454" "3" \
    "10000" \
    "$ADMIN_ADDRESS" \
    "'ipfs://debt-terms'" \
    "0" "0x555331323334353637383930" "12" \
    "$MATURITY_DATE" \
    "500" \
    "1000" \
    "0x0000000000000000000000000000000000000000000000000000000000000000" \
    "0x0000000000000000000000000000000000000000000000000000000000000000" \
    "$SALT_DEBT"
echo ""

# Test 5: Query deployment tracking
echo -e "${BLUE}=== Test 5: Query Deployment Tracking ===${NC}"
call_factory "get_deployment_count"

# Get deployments at indices
echo "Getting deployment at index 0:"
call_factory "get_deployment_at_index" "0" "0"

echo "Getting deployment at index 1:"
call_factory "get_deployment_at_index" "1" "0"

echo "Getting deployment at index 2:"  
call_factory "get_deployment_at_index" "2" "0"
echo ""

echo -e "${GREEN}🎉 Factory Testing Complete!${NC}"
echo ""
echo -e "${BLUE}=== Test Summary ===${NC}"
echo "✓ Factory configuration queries"
echo "✓ Standard CMTAT deployment"
echo "✓ Light CMTAT deployment"  
echo "✓ Debt CMTAT deployment"
echo "✓ Deployment tracking queries"
echo ""
echo -e "${BLUE}🔗 View transactions on Starkscan:${NC}"
echo "https://sepolia.starkscan.co/contract/${FACTORY_ADDRESS}"
echo ""
echo -e "${GREEN}All tests passed! The CMTAT Factory is working correctly.${NC}"
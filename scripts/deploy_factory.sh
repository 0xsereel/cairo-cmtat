#!/bin/bash

# CMTAT Factory Deployment Wrapper
# This script provides options to deploy the factory using different tools

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== CMTAT Factory Deployment Wrapper ===${NC}"
echo ""
echo "Choose your deployment method:"
echo "1) Deploy with sncast (recommended for new deployments)"
echo "2) Deploy with starkli (simple deployment with known class hashes)"
echo ""

# Check if an argument was provided to skip the interactive prompt
if [ "$#" -eq 1 ]; then
    case $1 in
        sncast|1)
            CHOICE=1
            ;;
        starkli|2)
            CHOICE=2
            ;;
        *)
            echo -e "${RED}Error: Invalid argument '$1'. Use 'sncast', 'starkli', '1', or '2'${NC}"
            exit 1
            ;;
    esac
else
    # Interactive mode
    read -p "Enter your choice (1 or 2): " CHOICE
fi

case $CHOICE in
    1)
        echo -e "${GREEN}✓ Using sncast deployment method${NC}"
        echo ""
        exec ./scripts/deploy_factory_sncast.sh
        ;;
    2)
        echo -e "${GREEN}✓ Using starkli deployment method${NC}"
        echo ""
        exec ./scripts/deploy_factory_starkli.sh
        ;;
    *)
        echo -e "${RED}Error: Invalid choice. Please select 1 or 2.${NC}"
        exit 1
        ;;
esac
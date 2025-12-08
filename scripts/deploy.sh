#!/bin/bash

# Cairo CMTAT Deployment Script v2.0
# Deploys ABI-compatible CMTAT ecosystem on Starknet
# Supports all four module variants: Light, Allowlist, Debt, Standard

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         Cairo CMTAT v2.0 Deployment Script               ║"
echo "║         ABI-Compatible Implementation                      ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Configuration
NETWORK="${NETWORK:-sepolia}"
ADMIN_ADDR="${ADMIN_ADDR:-0x04be1751352810aa8ad733c0f51d952ec4f96efee175ab0cb0da2d2ea537f50}"
INITIAL_SUPPLY="${INITIAL_SUPPLY:-1000000}"  # 1M tokens (will be multiplied by 10^18)

echo "Configuration:"
echo "  Network: $NETWORK"
echo "  Admin: $ADMIN_ADDR"
echo "  Initial Supply: $INITIAL_SUPPLY tokens"
echo ""

# Build contracts
echo "📦 Building contracts..."
scarb build
echo "✅ Build complete"
echo ""

# Deploy Light CMTAT (minimal feature set)
echo "═══════════════════════════════════════════════════════════"
echo "🪶 Deploying Light CMTAT"
echo "═══════════════════════════════════════════════════════════"
echo "Constructor parameters:"
echo "  - admin: $ADMIN_ADDR"
echo "  - name: 'Light CMTAT'"
echo "  - symbol: 'LCMTAT'"
echo "  - initial_supply: $INITIAL_SUPPLY"
echo "  - recipient: $ADMIN_ADDR"
echo ""

# Get class hash from build artifacts
LIGHT_CLASS_HASH=$(jq -r '.class_hash' target/dev/cairo_cmtat_LightCMTAT.contract_class.json 2>/dev/null || echo "")

if [ -z "$LIGHT_CLASS_HASH" ]; then
    echo "❌ Failed to read Light CMTAT class hash from artifacts"
    LIGHT_CMTAT="FAILED"
else
    echo "Class Hash: $LIGHT_CLASS_HASH"
    
    LIGHT_CMTAT=$(starkli deploy \
      "$LIGHT_CLASS_HASH" \
      --account ~/.starkli-wallets/deployer/account.json \
      --keystore ~/.starkli-wallets/deployer/keystore.json \
      --rpc https://starknet-sepolia.public.blastapi.io/rpc/v0.7 \
      $ADMIN_ADDR \
      0 0x4c6967687420434d544154 12 \
      0 0x4c434d544154 7 \
      $INITIAL_SUPPLY 0 \
      $ADMIN_ADDR | grep "Contract deployed:" | cut -d' ' -f3) || {
        echo "⚠️  Light CMTAT deployment failed or timed out"
        LIGHT_CMTAT="FAILED"
    }
    
    if [ "$LIGHT_CMTAT" != "FAILED" ]; then
        echo "✅ Light CMTAT: $LIGHT_CMTAT"
    fi
fi
echo ""

# Deploy Allowlist CMTAT (engines set after deployment)
echo "═══════════════════════════════════════════════════════════"
echo "✅ Deploying Allowlist CMTAT"
echo "═══════════════════════════════════════════════════════════"
echo "Constructor parameters:"
echo "  - admin: $ADMIN_ADDR"
echo "  - name: 'Allowlist CMTAT'"
echo "  - symbol: 'ACMTAT'"
echo "  - initial_supply: $INITIAL_SUPPLY"
echo "  - recipient: $ADMIN_ADDR"
echo ""

ALLOWLIST_CLASS_HASH=$(jq -r '.class_hash' target/dev/cairo_cmtat_AllowlistCMTAT.contract_class.json 2>/dev/null || echo "")

if [ -z "$ALLOWLIST_CLASS_HASH" ]; then
    echo "❌ Failed to read Allowlist CMTAT class hash from artifacts"
    ALLOWLIST_CMTAT="FAILED"
else
    echo "Class Hash: $ALLOWLIST_CLASS_HASH"
    
    ALLOWLIST_CMTAT=$(starkli deploy \
      "$ALLOWLIST_CLASS_HASH" \
      --account ~/.starkli-wallets/deployer/account.json \
      --keystore ~/.starkli-wallets/deployer/keystore.json \
      --rpc https://starknet-sepolia.public.blastapi.io/rpc/v0.7 \
      $ADMIN_ADDR \
      0 0x416c6c6f776c69737420434d544154 16 \
      0 0x41434d544154 7 \
      $INITIAL_SUPPLY 0 \
      $ADMIN_ADDR | grep "Contract deployed:" | cut -d' ' -f3) || {
        echo "⚠️  Allowlist CMTAT deployment failed or timed out"
        ALLOWLIST_CMTAT="FAILED"
    }
    
    if [ "$ALLOWLIST_CMTAT" != "FAILED" ]; then
        echo "✅ Allowlist CMTAT: $ALLOWLIST_CMTAT"
    fi
fi
echo ""

# Deploy Debt CMTAT (debt securities support)
echo "═══════════════════════════════════════════════════════════"
echo "💰 Deploying Debt CMTAT"
echo "═══════════════════════════════════════════════════════════"
echo "Constructor parameters:"
echo "  - admin: $ADMIN_ADDR"
echo "  - name: 'Debt CMTAT'"
echo "  - symbol: 'DCMTAT'"
echo "  - initial_supply: $INITIAL_SUPPLY"
echo "  - recipient: $ADMIN_ADDR"
echo ""

DEBT_CLASS_HASH=$(jq -r '.class_hash' target/dev/cairo_cmtat_DebtCMTAT.contract_class.json 2>/dev/null || echo "")

if [ -z "$DEBT_CLASS_HASH" ]; then
    echo "❌ Failed to read Debt CMTAT class hash from artifacts"
    DEBT_CMTAT="FAILED"
else
    echo "Class Hash: $DEBT_CLASS_HASH"
    
    DEBT_CMTAT=$(starkli deploy \
      "$DEBT_CLASS_HASH" \
      --account ~/.starkli-wallets/deployer/account.json \
      --keystore ~/.starkli-wallets/deployer/keystore.json \
      --rpc https://starknet-sepolia.public.blastapi.io/rpc/v0.7 \
      $ADMIN_ADDR \
      0 0x4465627420434d544154 11 \
      0 0x44434d544154 7 \
      $INITIAL_SUPPLY 0 \
      $ADMIN_ADDR | grep "Contract deployed:" | cut -d' ' -f3) || {
        echo "⚠️  Debt CMTAT deployment failed or timed out"
        DEBT_CMTAT="FAILED"
    }
    
    if [ "$DEBT_CMTAT" != "FAILED" ]; then
        echo "✅ Debt CMTAT: $DEBT_CMTAT"
    fi
fi
echo ""

# Deploy Standard CMTAT (engines set after deployment)
echo "═══════════════════════════════════════════════════════════"
echo "⭐ Deploying Standard CMTAT"
echo "═══════════════════════════════════════════════════════════"
echo "Constructor parameters:"
echo "  - admin: $ADMIN_ADDR"
echo "  - name: 'Standard CMTAT'"
echo "  - symbol: 'SCMTAT'"
echo "  - initial_supply: $INITIAL_SUPPLY"
echo "  - recipient: $ADMIN_ADDR"
echo ""

STANDARD_CLASS_HASH=$(jq -r '.class_hash' target/dev/cairo_cmtat_StandardCMTAT.contract_class.json 2>/dev/null || echo "")

if [ -z "$STANDARD_CLASS_HASH" ]; then
    echo "❌ Failed to read Standard CMTAT class hash from artifacts"
    STANDARD_CMTAT="FAILED"
else
    echo "Class Hash: $STANDARD_CLASS_HASH"
    
    STANDARD_CMTAT=$(starkli deploy \
      "$STANDARD_CLASS_HASH" \
      --account ~/.starkli-wallets/deployer/account.json \
      --keystore ~/.starkli-wallets/deployer/keystore.json \
      --rpc https://starknet-sepolia.public.blastapi.io/rpc/v0.7 \
      $ADMIN_ADDR \
      0 0x5374616e6461726420434d544154 14 \
      0 0x53434d544154 7 \
      $INITIAL_SUPPLY 0 \
      $ADMIN_ADDR | grep "Contract deployed:" | cut -d' ' -f3) || {
        echo "⚠️  Standard CMTAT deployment failed or timed out"
        STANDARD_CMTAT="FAILED"
    }
    
    if [ "$STANDARD_CMTAT" != "FAILED" ]; then
        echo "✅ Standard CMTAT: $STANDARD_CMTAT"
    fi
fi
echo ""

# Summary
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              Deployment Summary                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Deployed Contracts:"
echo ""
echo "Light CMTAT:     ${LIGHT_CMTAT}"
echo "Allowlist CMTAT: ${ALLOWLIST_CMTAT}"
echo "Debt CMTAT:      ${DEBT_CMTAT}"
echo "Standard CMTAT:  ${STANDARD_CMTAT}"
echo ""

# Update .env file
echo "💾 Updating .env file..."
cat > .env << EOF
# Cairo CMTAT v2.0 Deployment Configuration
# Generated on $(date)
# ABI-Compatible Implementation

# Network Configuration
NETWORK="$NETWORK"
ADMIN_ADDR="$ADMIN_ADDR"

# CMTAT Contract Addresses
LIGHT_CMTAT="$LIGHT_CMTAT"
ALLOWLIST_CMTAT="$ALLOWLIST_CMTAT"
DEBT_CMTAT="$DEBT_CMTAT"
STANDARD_CMTAT="$STANDARD_CMTAT"

# Class Hashes
LIGHT_CLASS_HASH="$LIGHT_CLASS_HASH"
ALLOWLIST_CLASS_HASH="$ALLOWLIST_CLASS_HASH"
DEBT_CLASS_HASH="$DEBT_CLASS_HASH"
STANDARD_CLASS_HASH="$STANDARD_CLASS_HASH"
EOF

echo "✅ Configuration saved to .env"
echo ""

# Check for failures
FAILED_COUNT=0
if [ "$LIGHT_CMTAT" = "FAILED" ]; then ((FAILED_COUNT++)); fi
if [ "$ALLOWLIST_CMTAT" = "FAILED" ]; then ((FAILED_COUNT++)); fi
if [ "$DEBT_CMTAT" = "FAILED" ]; then ((FAILED_COUNT++)); fi
if [ "$STANDARD_CMTAT" = "FAILED" ]; then ((FAILED_COUNT++)); fi

if [ $FAILED_COUNT -eq 0 ]; then
    echo "🎉 All contracts deployed successfully!"
    echo ""
    echo "📖 Next Steps:"
    echo "   1. source .env"
    echo "   2. Verify contracts on Starkscan"
    echo "   3. Set up engine integrations (if needed)"
    echo "   4. Run integration tests"
    echo ""
    echo "🔗 Starkscan URLs:"
    if [ "$LIGHT_CMTAT" != "FAILED" ]; then
        echo "   Light: https://sepolia.starkscan.co/contract/$LIGHT_CMTAT"
    fi
    if [ "$ALLOWLIST_CMTAT" != "FAILED" ]; then
        echo "   Allowlist: https://sepolia.starkscan.co/contract/$ALLOWLIST_CMTAT"
    fi
    if [ "$DEBT_CMTAT" != "FAILED" ]; then
        echo "   Debt: https://sepolia.starkscan.co/contract/$DEBT_CMTAT"
    fi
    if [ "$STANDARD_CMTAT" != "FAILED" ]; then
        echo "   Standard: https://sepolia.starkscan.co/contract/$STANDARD_CMTAT"
    fi
else
    echo "⚠️  Warning: $FAILED_COUNT contract(s) failed to deploy"
    echo ""
    echo "Troubleshooting:"
    echo "  - Check network connectivity"
    echo "  - Verify account has sufficient funds"
    echo "  - Ensure build artifacts exist in target/dev/"
    echo "  - Try deploying failed contracts manually"
    echo ""
    echo "Manual Deployment Commands:"
    if [ "$LIGHT_CMTAT" = "FAILED" ] && [ -n "$LIGHT_CLASS_HASH" ]; then
        echo ""
        echo "# Light CMTAT:"
        echo "starkli deploy $LIGHT_CLASS_HASH \\"
        echo "  $ADMIN_ADDR \\"
        echo "  0 0x4c6967687420434d544154 12 \\"
        echo "  0 0x4c434d544154 7 \\"
        echo "  $INITIAL_SUPPLY 0 \\"
        echo "  $ADMIN_ADDR"
    fi
    if [ "$ALLOWLIST_CMTAT" = "FAILED" ] && [ -n "$ALLOWLIST_CLASS_HASH" ]; then
        echo ""
        echo "# Allowlist CMTAT:"
        echo "starkli deploy $ALLOWLIST_CLASS_HASH \\"
        echo "  $ADMIN_ADDR \\"
        echo "  0 0x416c6c6f776c69737420434d544154 16 \\"
        echo "  0 0x41434d544154 7 \\"
        echo "  $INITIAL_SUPPLY 0 \\"
        echo "  $ADMIN_ADDR"
    fi
    if [ "$DEBT_CMTAT" = "FAILED" ] && [ -n "$DEBT_CLASS_HASH" ]; then
        echo ""
        echo "# Debt CMTAT:"
        echo "starkli deploy $DEBT_CLASS_HASH \\"
        echo "  $ADMIN_ADDR \\"
        echo "  0 0x4465627420434d544154 11 \\"
        echo "  0 0x44434d544154 7 \\"
        echo "  $INITIAL_SUPPLY 0 \\"
        echo "  $ADMIN_ADDR"
    fi
    if [ "$STANDARD_CMTAT" = "FAILED" ] && [ -n "$STANDARD_CLASS_HASH" ]; then
        echo ""
        echo "# Standard CMTAT:"
        echo "starkli deploy $STANDARD_CLASS_HASH \\"
        echo "  $ADMIN_ADDR \\"
        echo "  0 0x5374616e6461726420434d544154 14 \\"
        echo "  0 0x53434d544154 7 \\"
        echo "  $INITIAL_SUPPLY 0 \\"
        echo "  $ADMIN_ADDR"
    fi
fi

echo ""
echo "═══════════════════════════════════════════════════════════"

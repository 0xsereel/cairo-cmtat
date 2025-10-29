#!/bin/bash

# Cairo CMTAT Quick Deploy Script
# Deploys the complete CMTAT ecosystem on Starknet Sepolia
# Uses proven deployment patterns and known working configurations

set -e

echo "=== Cairo CMTAT Quick Deploy ==="
echo "Network: sepolia"
echo "Admin: 0x04be1751352810aa8ad733c0f51d952ec4f96efee175ab0cb0da2d2ea537f50"
echo ""

# Build contracts
echo "=== Building contracts ==="
scarb build
echo "✅ Build complete"
echo ""

# Deploy Rule Engine
echo "=== Deploying Rule Engine ==="
echo "Class Hash: 0x05fd8bb77a68906ee3c78ac8e9e2d66b6b9a6f66b4c6becd2a481c2e52f2b0fd"

RULE_ENGINE=$(starkli deploy \
  0x05fd8bb77a68906ee3c78ac8e9e2d66b6b9a6f66b4c6becd2a481c2e52f2b0fd \
  --account ~/.starkli-wallets/deployer/account.json \
  --keystore ~/.starkli-wallets/deployer/keystore.json \
  --rpc https://starknet-sepolia.public.blastapi.io/rpc/v0.7 \
  0x04be1751352810aa8ad733c0f51d952ec4f96efee175ab0cb0da2d2ea537f50 | grep "Contract deployed:" | cut -d' ' -f3)

if [ -z "$RULE_ENGINE" ]; then
    echo "❌ Failed to deploy Rule Engine"
    exit 1
fi
echo "✅ Rule Engine: $RULE_ENGINE"

# Deploy Snapshot Engine
echo ""
echo "=== Deploying Snapshot Engine ==="
echo "Class Hash: 0x0019f4eaac8c4b0e5c2b9ca55be9b5cc9df16ee4f31c25ff2f5bc87000a3b4bf"

SNAPSHOT_ENGINE=$(starkli deploy \
  0x0019f4eaac8c4b0e5c2b9ca55be9b5cc9df16ee4f31c25ff2f5bc87000a3b4bf \
  --account ~/.starkli-wallets/deployer/account.json \
  --keystore ~/.starkli-wallets/deployer/keystore.json \
  --rpc https://starknet-sepolia.public.blastapi.io/rpc/v0.7 \
  0x04be1751352810aa8ad733c0f51d952ec4f96efee175ab0cb0da2d2ea537f50 | grep "Contract deployed:" | cut -d' ' -f3)

if [ -z "$SNAPSHOT_ENGINE" ]; then
    echo "❌ Failed to deploy Snapshot Engine"
    exit 1
fi
echo "✅ Snapshot Engine: $SNAPSHOT_ENGINE"

# Deploy Standard CMTAT
echo ""
echo "=== Deploying Standard CMTAT ==="
echo "Class Hash: 0x0156438638cbac97e09e5781c66d4e23092d43b85c94286d11578f6b604a6463"
echo "Using ByteArray encoding: name='Standard CMTAT', symbol='SCMTAT', version='V0.0.0'"

STANDARD_CMTAT=$(starkli deploy \
  0x0156438638cbac97e09e5781c66d4e23092d43b85c94286d11578f6b604a6463 \
  --account ~/.starkli-wallets/deployer/account.json \
  --keystore ~/.starkli-wallets/deployer/keystore.json \
  --rpc https://starknet-sepolia.public.blastapi.io/rpc/v0.7 \
  0x04be1751352810aa8ad733c0f51d952ec4f96efee175ab0cb0da2d2ea537f50 \
  0 0x5374616e6461726420434d544154 14 \
  0 0x53434d544154 7 \
  0 0x56302e302e30 6 \
  18 \
  0x04be1751352810aa8ad733c0f51d952ec4f96efee175ab0cb0da2d2ea537f50 \
  "$RULE_ENGINE" \
  "$SNAPSHOT_ENGINE" | grep "Contract deployed:" | cut -d' ' -f3)

if [ -z "$STANDARD_CMTAT" ]; then
    echo "❌ Failed to deploy Standard CMTAT"
    STANDARD_CMTAT="DEPLOY_MANUALLY"
else
    echo "✅ Standard CMTAT: $STANDARD_CMTAT"
fi

# Deploy Light CMTAT
echo ""
echo "=== Deploying Light CMTAT ==="
echo "Class Hash: 0x0040ce9334f9146f53e6e32c7b8fe9644cc5d6cece7507768cdbfecbf57b27f1"
echo "Using ByteArray encoding: name='Light CMTAT', symbol='LCMTAT', version='V0.0.0'"

LIGHT_CMTAT=$(starkli deploy \
  0x0040ce9334f9146f53e6e32c7b8fe9644cc5d6cece7507768cdbfecbf57b27f1 \
  --account ~/.starkli-wallets/deployer/account.json \
  --keystore ~/.starkli-wallets/deployer/keystore.json \
  --rpc https://starknet-sepolia.public.blastapi.io/rpc/v0.7 \
  0x04be1751352810aa8ad733c0f51d952ec4f96efee175ab0cb0da2d2ea537f50 \
  0 0x4c6967687420434d544154 12 \
  0 0x4c434d544154 7 \
  0 0x56302e302e30 6 \
  18 \
  0x04be1751352810aa8ad733c0f51d952ec4f96efee175ab0cb0da2d2ea537f50 \
  "$RULE_ENGINE" \
  "$SNAPSHOT_ENGINE" | grep "Contract deployed:" | cut -d' ' -f3)

if [ -z "$LIGHT_CMTAT" ]; then
    echo "❌ Failed to deploy Light CMTAT"
    LIGHT_CMTAT="DEPLOY_MANUALLY"
else
    echo "✅ Light CMTAT: $LIGHT_CMTAT"
fi

# Deploy Debt CMTAT
echo ""
echo "=== Deploying Debt CMTAT ==="
echo "Class Hash: 0x073df1d757f9927b737ae61d1b350aeefa4df2bf1cfc73c47c017b9e80e246e7"
echo "Using ByteArray encoding: name='Debt CMTAT', symbol='DCMTAT', version='V0.0.0'"

DEBT_CMTAT=$(starkli deploy \
  0x073df1d757f9927b737ae61d1b350aeefa4df2bf1cfc73c47c017b9e80e246e7 \
  --account ~/.starkli-wallets/deployer/account.json \
  --keystore ~/.starkli-wallets/deployer/keystore.json \
  --rpc https://starknet-sepolia.public.blastapi.io/rpc/v0.7 \
  0x04be1751352810aa8ad733c0f51d952ec4f96efee175ab0cb0da2d2ea537f50 \
  0 0x4465627420434d544154 11 \
  0 0x44434d544154 7 \
  0 0x56302e302e30 6 \
  18 \
  0x04be1751352810aa8ad733c0f51d952ec4f96efee175ab0cb0da2d2ea537f50 \
  "$RULE_ENGINE" \
  "$SNAPSHOT_ENGINE" | grep "Contract deployed:" | cut -d' ' -f3) || {
    echo "⚠️  Debt CMTAT deployment may have timed out"
    DEBT_CMTAT="DEPLOY_MANUALLY"
}

if [ "$DEBT_CMTAT" = "DEPLOY_MANUALLY" ]; then
    echo "⚠️  Debt CMTAT deployment incomplete"
    echo "    Manual deployment required or check existing deployment"
else
    echo "✅ Debt CMTAT: $DEBT_CMTAT"
fi

# Update .env file
echo ""
echo "=== Updating .env file ==="
cat > .env << EOF
# Cairo CMTAT Deployment Configuration
# Generated on $(date)

# Network Configuration
NETWORK="sepolia"
ADMIN_ADDR="0x04be1751352810aa8ad733c0f51d952ec4f96efee175ab0cb0da2d2ea537f50"

# Engine Contracts
RULE_ENGINE="$RULE_ENGINE"
SNAPSHOT_ENGINE="$SNAPSHOT_ENGINE"

# CMTAT Contracts
STANDARD_CMTAT="$STANDARD_CMTAT"
LIGHT_CMTAT="$LIGHT_CMTAT"
DEBT_CMTAT="$DEBT_CMTAT"
EOF

echo ""
echo "🎉 Deployment Complete!"
echo ""
echo "=== Contract Addresses ==="
echo "Rule Engine:     $RULE_ENGINE"
echo "Snapshot Engine: $SNAPSHOT_ENGINE"
echo "Standard CMTAT:  $STANDARD_CMTAT"
echo "Light CMTAT:     $LIGHT_CMTAT"
echo "Debt CMTAT:      $DEBT_CMTAT"
echo ""
echo "📄 Configuration saved to .env"
echo ""
if [[ "$STANDARD_CMTAT" == "DEPLOY_MANUALLY" || "$LIGHT_CMTAT" == "DEPLOY_MANUALLY" || "$DEBT_CMTAT" == "DEPLOY_MANUALLY" ]]; then
    echo "⚠️  Note: Some contracts may need manual deployment"
    echo "   Check the output above and deploy manually if needed"
    echo "   Known working deployment addresses are in README.md"
fi
echo ""
echo "🔗 View contracts on Starkscan:"
echo "https://sepolia.starkscan.co/contract/[CONTRACT_ADDRESS]"
echo ""
echo "📋 Next steps:"
echo "   1. source .env"
echo "   2. ./scripts/test_deployment.sh"
echo "   3. ./scripts/snapshot_demo.sh"
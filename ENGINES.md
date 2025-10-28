# CMTAT Engines Guide

This guide explains how to deploy and use Rule Engines and Snapshot Engines with CMTAT tokens on Starknet.

## Overview

CMTAT engines extend token functionality:
- **Rule Engine**: Controls transfer restrictions (e.g., whitelisting, max balances)
- **Snapshot Engine**: Records historical token balances for dividends, voting, etc.

## Rule Engine

### What is a Rule Engine?

A Rule Engine implements ERC-1404 compliant transfer restrictions. It determines whether a transfer should be allowed and provides human-readable messages for restrictions.

### Deploy a Rule Engine

```bash
# Deploy Whitelist Rule Engine
./scripts/deploy_engines.sh \
  --engine rule \
  --token-address 0x<YOUR_TOKEN_ADDRESS> \
  --owner 0x<YOUR_ADDRESS> \
  --max-balance 1000000  # Optional: max tokens per address
```

### Configure the Rule Engine

#### 1. Add addresses to whitelist

```bash
# Add single address
starkli invoke <RULE_ENGINE_ADDRESS> add_to_whitelist \
  <ADDRESS_TO_WHITELIST> \
  --network sepolia \
  --account default

# Batch add multiple addresses
starkli invoke <RULE_ENGINE_ADDRESS> batch_add_to_whitelist \
  "[<ADDR1>,<ADDR2>,<ADDR3>]" \
  --network sepolia \
  --account default
```

#### 2. Check if address is whitelisted

```bash
starkli call <RULE_ENGINE_ADDRESS> is_address_valid \
  <ADDRESS> \
  --network sepolia
```

#### 3. Test transfer restrictions

```bash
# Returns restriction code (0 = no restriction)
starkli call <RULE_ENGINE_ADDRESS> detect_transfer_restriction \
  <FROM_ADDRESS> \
  <TO_ADDRESS> \
  <AMOUNT> \
  --network sepolia

# Get human-readable message for restriction code
starkli call <RULE_ENGINE_ADDRESS> message_for_restriction_code \
  <CODE> \
  --network sepolia
```

### Restriction Codes

| Code | Meaning |
|------|---------|
| 0    | No restriction - transfer allowed |
| 1    | Recipient not whitelisted |
| 2    | Sender not whitelisted |
| 3    | Exceeds maximum balance limit |

### Integration with CMTAT Token

To integrate the Rule Engine with your CMTAT token, the token contract should:

1. Store the Rule Engine address
2. Call `detect_transfer_restriction()` before each transfer
3. Reject transfers if restriction code is non-zero
4. Call `on_transfer_executed()` after successful transfers

## Snapshot Engine

### What is a Snapshot Engine?

A Snapshot Engine records token balances at specific points in time. This is useful for:
- **Dividends**: Calculate distributions based on holdings at specific date
- **Voting**: Determine voting power based on past holdings
- **Compliance**: Maintain historical records for regulatory requirements

### Deploy a Snapshot Engine

```bash
# Deploy Snapshot Engine
./scripts/deploy_engines.sh \
  --engine snapshot \
  --token-address 0x<YOUR_TOKEN_ADDRESS> \
  --owner 0x<YOUR_ADDRESS>
```

### Using the Snapshot Engine

#### 1. Schedule a snapshot

```bash
# Schedule snapshot for specific timestamp
starkli invoke <SNAPSHOT_ENGINE_ADDRESS> schedule_snapshot \
  <TIMESTAMP> \
  --network sepolia \
  --account default

# Returns snapshot ID
```

#### 2. Record token state (called by token contract)

When a snapshot time is reached, the token contract should call:

```bash
# Record total supply snapshot
starkli invoke <SNAPSHOT_ENGINE_ADDRESS> record_snapshot \
  <SNAPSHOT_ID> \
  <TOTAL_SUPPLY> \
  --network sepolia \
  --account <TOKEN_CONTRACT>

# Record individual balance
starkli invoke <SNAPSHOT_ENGINE_ADDRESS> record_balance \
  <SNAPSHOT_ID> \
  <ACCOUNT> \
  <BALANCE> \
  --network sepolia \
  --account <TOKEN_CONTRACT>

# Batch record multiple balances
starkli invoke <SNAPSHOT_ENGINE_ADDRESS> batch_record_balances \
  <SNAPSHOT_ID> \
  "[<ACCOUNT1>,<ACCOUNT2>]" \
  "[<BALANCE1>,<BALANCE2>]" \
  --network sepolia \
  --account <TOKEN_CONTRACT>
```

#### 3. Query historical balances

```bash
# Get snapshot info
starkli call <SNAPSHOT_ENGINE_ADDRESS> get_snapshot \
  <SNAPSHOT_ID> \
  --network sepolia

# Query balance at snapshot
starkli call <SNAPSHOT_ENGINE_ADDRESS> balance_of_at \
  <ACCOUNT> \
  <SNAPSHOT_ID> \
  --network sepolia

# Query total supply at snapshot
starkli call <SNAPSHOT_ENGINE_ADDRESS> total_supply_at \
  <SNAPSHOT_ID> \
  --network sepolia

# Batch query multiple balances
starkli call <SNAPSHOT_ENGINE_ADDRESS> batch_balance_of_at \
  "[<ACCOUNT1>,<ACCOUNT2>,<ACCOUNT3>]" \
  <SNAPSHOT_ID> \
  --network sepolia
```

## Complete Example: Deploying Full CMTAT with Engines

### Step 1: Deploy CMTAT Token

```bash
./scripts/deploy_cmtat.sh \
  --type standard \
  --name "My Security Token" \
  --symbol "MST" \
  --network sepolia
```

Save the token address: `TOKEN_ADDR=0x...`

### Step 2: Deploy Rule Engine

```bash
./scripts/deploy_engines.sh \
  --engine rule \
  --token-address $TOKEN_ADDR \
  --owner 0x<YOUR_ADDRESS> \
  --network sepolia
```

Save the rule engine address: `RULE_ADDR=0x...`

### Step 3: Deploy Snapshot Engine

```bash
./scripts/deploy_engines.sh \
  --engine snapshot \
  --token-address $TOKEN_ADDR \
  --owner 0x<YOUR_ADDRESS> \
  --network sepolia
```

Save the snapshot engine address: `SNAPSHOT_ADDR=0x...`

### Step 4: Configure Rule Engine

```bash
# Whitelist investor addresses
starkli invoke $RULE_ADDR batch_add_to_whitelist \
  "[0x<INVESTOR1>,0x<INVESTOR2>,0x<INVESTOR3>]" \
  --network sepolia \
  --account default
```

### Step 5: Schedule Snapshots

```bash
# Schedule quarterly snapshots
# Timestamp for March 31, 2025: 1743427200
starkli invoke $SNAPSHOT_ADDR schedule_snapshot \
  1743427200 \
  --network sepolia \
  --account default
```

### Step 6: Test the Setup

```bash
# Check transfer restriction
starkli call $RULE_ADDR detect_transfer_restriction \
  0x<FROM> \
  0x<TO> \
  1000 \
  --network sepolia

# Should return 0 if both addresses are whitelisted
```

## Best Practices

### Rule Engine

1. **Whitelist Management**
   - Always whitelist the zero address for minting/burning
   - Keep whitelist updated as investors join/leave
   - Use batch operations for efficiency

2. **Testing**
   - Test all restriction scenarios before mainnet
   - Verify restriction messages are clear
   - Test edge cases (zero amounts, large amounts)

3. **Security**
   - Only grant owner role to trusted addresses
   - Consider using multisig for owner
   - Audit rule logic thoroughly

### Snapshot Engine

1. **Scheduling**
   - Schedule snapshots in advance
   - Use consistent timing (e.g., end of quarter)
   - Document snapshot schedule for transparency

2. **Recording**
   - Automate snapshot recording via backend service
   - Record all active holders
   - Verify recordings are complete

3. **Querying**
   - Use batch queries for efficiency
   - Cache results for frequently accessed snapshots
   - Provide UI for easy balance lookups

## Troubleshooting

### Rule Engine Issues

**Problem**: Transfers failing unexpectedly
- **Solution**: Check both sender and recipient are whitelisted
- **Check**: Call `is_address_valid()` for both addresses

**Problem**: Can't add addresses to whitelist
- **Solution**: Verify you have owner role
- **Check**: Call `owner()` on the engine contract

### Snapshot Engine Issues

**Problem**: Can't record snapshot
- **Solution**: Only token contract can record
- **Check**: Ensure caller is the token contract address

**Problem**: Balance queries return 0
- **Solution**: Ensure snapshot was properly recorded
- **Check**: Call `get_snapshot()` to verify snapshot exists

## Security Considerations

1. **Access Control**
   - Only owner can manage whitelist
   - Only token contract can record snapshots
   - Protect private keys securely

2. **Validation**
   - Always validate restriction codes before transfers
   - Verify snapshot IDs exist before querying
   - Check timestamps are reasonable

3. **Monitoring**
   - Monitor engine events for suspicious activity
   - Track failed transfers and restriction reasons
   - Audit snapshot recordings regularly

## Integration with Token Contracts

To fully integrate engines with CMTAT tokens, implement:

1. **Rule Engine Integration**
   ```cairo
   // In transfer logic
   let restriction = rule_engine.detect_transfer_restriction(from, to, amount);
   assert(restriction == 0, 'Transfer restricted');
   
   // After successful transfer
   rule_engine.on_transfer_executed(from, to, amount);
   ```

2. **Snapshot Engine Integration**
   ```cairo
   // When snapshot time is reached
   snapshot_engine.record_snapshot(snapshot_id, self.total_supply());
   
   // Record balances for all holders
   snapshot_engine.batch_record_balances(snapshot_id, accounts, balances);
   ```

## Additional Resources

- [CMTAT Specification](https://github.com/CMTA/CMTAT)
- [ERC-1404 Standard](https://github.com/ethereum/EIPs/issues/1404)
- [Starknet Documentation](https://docs.starknet.io)
- [OpenZeppelin Cairo Contracts](https://github.com/OpenZeppelin/cairo-contracts)

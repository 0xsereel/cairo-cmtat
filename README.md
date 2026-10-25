# cairo-cmtat

A Cairo port of [CMTAT](https://github.com/CMTA/CMTAT), the CMTA token framework for tokenized securities, for Starknet. The target is CMTAT **v3.3.0** (commit `3d9b0e9`).

The token is built from one Cairo component per CMTAT module. These components are composed into five upgradeable presets, each matching a CMTAT deployment variant:

| Preset | CMTAT variant (base) | What it adds |
|---|---|---|
| `CMTATLight` | Light (`CMTATBaseCore`) | ERC-20, pause and deactivation, address freeze, mint, burn, forced burn |
| `CMTATAllowlist` | Allowlist (`CMTATBaseAllowlist`) | Common modules (below), plus an allowlist that is enabled at deployment |
| `CMTATStandard` | Standard (`CMTATBaseERC7551Enforcement`) | Common modules, RuleEngine, ERC-1404, burn-from and self-burn, ERC-7551 overloads |
| `CMTATDebt` | Debt (`CMTATBaseDebt`) | Common modules, RuleEngine, SnapshotEngine, debt and credit-event information |
| `CMTATSnapshot` | Snapshot (`CMTATBaseERC2771Snapshot`) | Common modules, RuleEngine, ERC-1404, burn-from and self-burn, SnapshotEngine |

The **common modules** are:
- pause and ERC-8343 deactivation;
- address freeze, partial freeze and forced transfer (ERC-3643 / ERC-7943);
- mint and burn;
- token attributes;
- extra information (token id, terms, information);
- ERC-1643 documents.

Light has neither partial freeze nor forced transfer. Instead it has a forced burn, which only works on a frozen address.

> **Status:** this code has not yet been audited. Sepolia class hashes will be added after the first declaration.

---

## Quick start

The toolchain is pinned in `.tool-versions`: Scarb 2.18.0 and Starknet Foundry 0.59.0. The project depends on OpenZeppelin Cairo v4.0.1.

```bash
scarb build                 # build all contracts
snforge test                # run the test suite
scripts/check_sizes.sh      # fail if any class is above 90% of the Starknet size limits
```

### Deploy

[`scripts/deploy.sh`](scripts/deploy.sh) wraps `sncast`. Each preset class is declared once per network, and every token after that is a cheap deploy of the same class.

```bash
cp .env.example .env        # fill in network, account and token settings
set -a; source .env; set +a
scripts/deploy.sh declare               # declare all presets (or: declare standard debt)
scripts/deploy.sh calldata standard     # preview the constructor calldata (offline)
scripts/deploy.sh deploy standard       # deploy one token
```

Each deployment is appended to `deployments/<network>.tsv`.

### Constructors

| Preset | Arguments |
|---|---|
| Light | `(admin, ERC20Attributes)` |
| Allowlist | `(admin, ERC20Attributes, ExtraInformationAttributes)` |
| Standard, Debt, Snapshot | `(admin, ERC20Attributes, ExtraInformationAttributes, rule_engine)` |

```cairo
struct ERC20Attributes { name: ByteArray, symbol: ByteArray, decimals: u8 }
struct ExtraInformationAttributes { token_id: ByteArray, terms: DocumentInfo, information: ByteArray }
struct DocumentInfo { name: ByteArray, uri: ByteArray, document_hash: u256 }
```

The constructor arguments work as follows:
- `admin` receives `DEFAULT_ADMIN_ROLE` and must not be zero.
- `decimals` is 0 for CMTAT compliance with Swiss law; other values are allowed.
- If `rule_engine` is zero, no RuleEngine is set.
- The SnapshotEngine is set after deployment, under `SNAPSHOOTER_ROLE`.
- The allowlist starts enabled and empty.

### Class hashes

These are release builds made with the pinned toolchain. Run `sncast utils class-hash --contract-name <name>` to reproduce them. Size is the CASM size as a share of the Starknet limit.

| Preset | Class hash | CASM size |
|---|---|---|
| `CMTATLight` | `0x011df70cf8970a4b3c630cde6dd8f4896b9f1e121d62965bcba56c50a3ce4947` | 32.3% |
| `CMTATAllowlist` | `0x060110932181cf77d34bc91c7876ecd1e347cfdab59001d00bc0f5b1538de60a` | 54.0% |
| `CMTATStandard` | `0x017142c73e963ae46857a0005fc07f8db3fd8da8b6c27140d4d73e374fee97c1` | 55.7% |
| `CMTATDebt` | `0x00deb81e3f3e7beb2050e211e72907bded190f068e041869a61f2b61b8a00ef1` | 62.7% |
| `CMTATSnapshot` | `0x05ae8444b4b62c44fecd05812a074ce5d6fa203c8c0061efd44115e03c482fbc` | 54.9% |

---

## ABI

Function names are snake_case versions of CMTAT's. Cairo has no overloading, so CMTAT overloads get suffixes:

| CMTAT | Cairo |
|---|---|
| `mint(account, value, data)` | `mint_with_data` |
| `burn(account, value, data)` | `burn_with_data` |
| `batchBurn(accounts, values, data)` | `batch_burn_with_data` |
| `burn(value)` (self-burn) | `burn_self` |
| `setAddressFrozen(account, isFrozen, data)` | `set_address_frozen_with_data` |
| `freezePartialTokens(account, value, data)`, `unfreezePartialTokens(...)`, `forcedTransfer(from, to, value, data)` | `freeze_partial_tokens_with_data`, `unfreeze_partial_tokens_with_data`, `forced_transfer_with_data` |
| `setAddressAllowlist(account, status, data)` | `set_address_allowlist_with_data` |
| RuleEngine `transferred(spender, from, to, value)` | `transferred_with_spender` |

Each interface below is listed with its functions and the presets that expose it. This table was generated from the release ABIs.

| Interface | Functions | Light | Allowlist | Standard | Debt | Snapshot |
|---|---|:-:|:-:|:-:|:-:|:-:|
| `IERC20`, `IERC20CamelOnly`, `IERC20Metadata` | standard ERC-20 (snake_case and camelCase), `name`, `symbol`, `decimals` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `IERC20BatchBalance` | `batch_balance_of` → `(balances, total_supply)` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `IAccessControl` | `has_role`, `get_role_admin`, `grant_role`, `revoke_role`, `renounce_role` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `ISRC5` | `supports_interface` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `IERC3643Pause`, `IERC8343` | `pause`, `unpause`, `paused`, `deactivate_contract`, `deactivated` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `IERC3643Enforcement`, `ICMTATEnforcement` | `set_address_frozen(_with_data)`, `batch_set_address_frozen`, `is_frozen` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `IERC7943FungibleSendReceiveCheck`, `IERC3643ComplianceRead`, `IERC7551Compliance` | `can_send`, `can_receive`, `can_transfer`, `can_transfer_from` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `IERC3643Mint`, `IERC3643BatchTransfer`, `IERC5679Mint` | `mint`, `batch_mint`, `batch_transfer`, `mint_with_data` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `IERC3643Burn`, `IERC5679Burn`, `IBurnBatchERC20`, `IBurnMintERC20` | `burn`, `batch_burn`, `burn_with_data`, `batch_burn_with_data`, `burn_and_mint` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `IERC3643ERC20Base`, `IERC3643Version` | `set_name`, `set_symbol`, `version` (`"3.3.0"`) | ✓ | ✓ | ✓ | ✓ | ✓ |
| `IUpgradeable`, `IUpgradeVersion` | `upgrade`, `initialized_version` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `IForcedBurnERC20` | `forced_burn(account, value, data)` | ✓ | | | | |
| `IERC3643ERC20Enforcement`, `IERC7943FungibleEnforcement` | `freeze_partial_tokens`, `unfreeze_partial_tokens`, `get_frozen_tokens`, `set_frozen_tokens`, `forced_transfer` | | ✓ | ✓ | ✓ | ✓ |
| `IERC7551ERC20Enforcement` | `get_active_balance_of`, `*_with_data` freeze, unfreeze and forced-transfer overloads | | ✓ | ✓ | | |
| `ICMTATBase` | `token_id`, `terms`, `information`, `set_token_id`, `set_terms`, `set_information` | | ✓ | ✓ | ✓ | ✓ |
| `IERC1643` | `get_document`, `get_all_documents`, `set_document`, `remove_document` | | ✓ | ✓ | ✓ | ✓ |
| `IAllowlistModule` | `set_address_allowlist(_with_data)`, `batch_set_address_allowlist`, `enable_allowlist`, `is_allowlist_enabled`, `is_allowlisted` | | ✓ | | | |
| `IValidationRuleEngine` | `rule_engine`, `set_rule_engine` | | | ✓ | ✓ | ✓ |
| `IERC1404`, `IERC1404Extend` | `detect_transfer_restriction(_from)`, `message_for_transfer_restriction` | | | ✓ | | ✓ |
| `IBurnFromERC20` | `burn_from`, `burn_self` | | | ✓ | | ✓ |
| `ISnapshotEngineModule` | `snapshot_engine`, `set_snapshot_engine` | | | | ✓ | ✓ |
| `IDebtModule` | `debt`, `credit_events`, `set_debt`, `set_debt_instrument`, `set_credit_events` | | | | ✓ | |

`tests/test_presets.cairo` checks this surface against the CMTAT variant table on every preset. A module a preset shouldn't have must answer `ENTRYPOINT_NOT_FOUND`.

---

## Roles

A role id is `selector!("<NAME>")`, the `sn_keccak` of the role name. This follows the OpenZeppelin Cairo convention, not Solidity's `keccak256`. `DEFAULT_ADMIN_ROLE` is `0`.

**The default admin holds every role**: `has_role(role, admin)` is true for any role, as with CMTAT's `hasRole` override. Each role's admin role is `DEFAULT_ADMIN_ROLE`.

| Role | Id | Gates |
|---|---|---|
| `DEFAULT_ADMIN_ROLE` | `0x0` | `grant_role` and `revoke_role`; `forced_transfer(_with_data)`, `forced_burn`, `deactivate_contract`, `set_rule_engine`, `set_name`, `set_symbol`, `upgrade`, and a new class's `migrate` |
| `PAUSER_ROLE` | `0x01d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a` | `pause`, `unpause` |
| `ENFORCER_ROLE` | `0x033ef39d76cc2c6090feab1c030bec6ab5db557f64df047a4c4f9b5953cf1df3` | `set_address_frozen(_with_data)`, `batch_set_address_frozen` |
| `ERC20ENFORCER_ROLE` | `0x022f75bf68b069bc8e2abd495a949fafec67a4e5a5b7cb36aedf0dd51eec7e72` | `freeze_partial_tokens(_with_data)`, `unfreeze_partial_tokens(_with_data)`, `set_frozen_tokens` |
| `MINTER_ROLE` | `0x032df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6` | `mint(_with_data)`, `batch_mint`, `batch_transfer`; the mint leg of `burn_and_mint` |
| `BURNER_ROLE` | `0x0011d16cbaffd01df69ce1c404f6340ee057498f5f00246190ea54220576a848` | `burn(_with_data)`, `batch_burn(_with_data)`; the burn leg of `burn_and_mint` |
| `BURNER_FROM_ROLE` | `0x03fe08abba057c54e6a28bce27ce8c53eb21d7a94376a70d475b5dee60b6c4e2` | `burn_from` |
| `BURNER_SELF_ROLE` | `0x03d9f3ea33477b975af6cd01437366c28412d5bd9b872fa0fc25bd3a160683af` | `burn_self` |
| `EXTRA_INFORMATION_ROLE` | `0x021df7a58eb4ea112afa962b8186161404ecda2e8fe97f8246026d02ad1a74b7` | `set_token_id`, `set_terms`, `set_information` |
| `DOCUMENT_ROLE` | `0x017c9aafbb91d54fb2041db1d5b172ea665309b32f5fffdbddf452802a1e3b20` | `set_document`, `remove_document` |
| `SNAPSHOOTER_ROLE` | `0x009a0fc49fc0600540f1d39e23454e1f6f215bc7505fa22b17c154616570ddef` | `set_snapshot_engine` |
| `ALLOWLIST_ROLE` | `0x02a560d834a19637eccba4611bbc09fb32970bb627da0a70f14f83fdc9822cbc` | `set_address_allowlist(_with_data)`, `batch_set_address_allowlist`, `enable_allowlist` |
| `DEBT_ROLE` | `0x02f3350ab30f55ce45863160fc345c1663d4633fe7cacfd3b9bbb6420a9147f8` | `set_debt`, `set_debt_instrument`, `set_credit_events` |

A call without the required role reverts with OpenZeppelin's `'Caller is missing role'`.

---

## Transfer validation

The checks and their order follow CMTAT v3.3.0. The same failure always produces the same error. `tests/test_validation_matrix.cairo` runs the full matrix against a mock token and every preset.

**Transfers** (`transfer`, `transfer_from`, `batch_transfer`):
1. **Active balance** (all presets except Light): a sender with frozen tokens can move only its unfrozen balance. Otherwise the transfer reverts with `ERC7943InsufficientUnfrozenBal(from, value, active)`.
2. **Allowlist** (Allowlist preset, when enabled): the spender (if any), then `from`, then `to`.
3. **Pause**.
4. **Address freeze**: the spender, then `from`, then `to`.
5. **RuleEngine**, if one is set.

These steps behave as follows:
- A transfer on a deactivated token reverts with the pause error. Deactivation requires the token to be paused and blocks unpausing.
- `transfer` passes no spender. `transfer_from` passes the caller as spender.

**Mint and burn:**
- Mint checks deactivation, then whether `to` is frozen.
- Burn checks deactivation, then whether `from` is frozen, then the active balance.
- Pause does not block mint or burn.
- Both call the RuleEngine with the operator as spender.

**Forced paths:**
- `forced_transfer` skips every compliance check and unfreezes only the shortfall.
- `forced_transfer` to address 0 burns. On every preset except Light, this is how frozen holdings are burned.
- `forced_transfer(from, from, …)` reverts.
- Light's `forced_burn` requires a frozen address.

**Approve:** `approve(spender, 0)` always succeeds, even while the token is paused or the owner is frozen. Any other value checks pause, then whether the owner is frozen (or not on the allowlist), then the spender.

**Reads:**
- `detect_transfer_restriction(_from)` returns the first code that applies, in this order:
  - `5`: spender frozen (`_from` only);
  - `6`: insufficient active balance;
  - `1`: deactivated;
  - `2`: paused;
  - `3`: `from` frozen;
  - `4`: `to` frozen;
  - then the RuleEngine's code (7–12);
  - otherwise `0`.

  This order intentionally differs from the revert order. Both paths agree on whether a transfer is allowed.
- `can_send`, `can_receive`, `can_transfer` and `can_transfer_from` follow the same checks.

---

## Engines

Engines live outside this repository, as they do in CMTA's own repositories. `src/mocks` has recorder engines for tests.

- **RuleEngine** (`IRuleEngine`):
  - The token calls `transferred(from, to, value)` or `transferred_with_spender(spender, from, to, value)` on every transfer, mint and burn. The engine can revert to block the operation.
  - Reads call `can_transfer(_from)`.
  - An engine that also implements `IRuleEngineERC1404` supplies the ERC-1404 codes 7–12 and their messages.
  - Calls into the engine are wrapped in OpenZeppelin's `ReentrancyGuard`.
- **SnapshotEngine** (`ISnapshotEngine`):
  - The token calls `operate_on_transfer(from, to, balance_from, balance_to, total_supply)` on every balance change, passing the balances and total supply from before the change.

## Interface Introspection (SRC5)

Each preset registers the same interfaces through SRC5 (`supports_interface`) that its CMTAT v3.3.0 base reports through ERC-165 (`supportsInterface`).

### Interface ids

An id is the XOR of the SNIP-5 extended selectors of its functions. Each selector is `sn_keccak` of the function's signature string, built with these rules:

- Type names are short: `ContractAddress`, `felt252`, `u8`, `u64`.
- A struct is written as the tuple of its fields:
  - `u256` → `(u128,u128)`
  - `ByteArray` → `(Array<bytes31>,felt252,u32)`
  - `Span<T>` → `(@Array<T>)`
- An enum is written as `E(...)`, so `bool` → `E((),())`.
- The output follows `->`, and is omitted when the function returns nothing. The `self` parameter is not included.

The ids use the Cairo function names. Where a Cairo name differs from CMTAT's, the CMTAT overload is in brackets, e.g. `mint_with_data` (`mint(account, value, data)`). CMTAT's ERC-165 id covers the same functions.

| Constant | Value | CMTAT ERC-165 id | Extended signatures |
|---|---|---|---|
| `ISRC5_ID` (OpenZeppelin) | `0x3f918d17e5ee77373b56385708f855659a07f75997f365cf87748628532a055` | `0x01ffc9a7` | `supports_interface(felt252)->E((),())` |
| `IACCESSCONTROL_ID` (OpenZeppelin) | `0x23700be02858dbe2ac4dc9c9f66d0b6b0ed81ec7f970ca6844500a56ff61751` | `0x7965db0b` | OpenZeppelin AccessControl |
| `IERC8343_ID` | `0xb0170a1ae08515ecaede32d780ec7e7d7dc84266f5e007cf6411db91ff8b` | `0xe9cd80b0` | `deactivate_contract()`<br>`deactivated()->E((),())` |
| `IERC5679_ID` | `0x33c89e5cd6ccac5fc9f984d94defdfc99b2cadda15b0422f41b9b848de233c8` | `0xd0017968` | `mint_with_data(ContractAddress,(u128,u128),(@Array<felt252>))` (`mint(account, value, data)`)<br>`burn_with_data(ContractAddress,(u128,u128),(@Array<felt252>))` (`burn(account, value, data)`) |
| `IERC7943_ID` | `0x14e4423410d8cc56f38ff233c6d8d427700f0c7929a1ef8c0c9d117955b3ec1` | `0x3edbb4c4` | `get_frozen_tokens(ContractAddress)->(u128,u128)`<br>`set_frozen_tokens(ContractAddress,(u128,u128))->E((),())`<br>`forced_transfer(ContractAddress,ContractAddress,(u128,u128))->E((),())`<br>`can_send(ContractAddress)->E((),())`<br>`can_receive(ContractAddress)->E((),())`<br>`can_transfer(ContractAddress,ContractAddress,(u128,u128))->E((),())` |
| `IERC1643_ID` | `0x1a10ec61334b275b2f19413a43f011e7465e9f29c94a34b07b7d33c2bb93d50` | `0xecfecec8` | `get_document(felt252)->((Array<bytes31>,felt252,u32),(u128,u128),u64)`<br>`get_all_documents()->Array<felt252>`<br>`set_document(felt252,(Array<bytes31>,felt252,u32),(u128,u128))`<br>`remove_document(felt252)` |
| `IERC1404_ID` | `0x3a3c667090ad0aa8f47799a4995ee74f3ca62bdaf5d64d75cd41596255f182a` | — | `detect_transfer_restriction(ContractAddress,ContractAddress,(u128,u128))->u8`<br>`message_for_transfer_restriction(u8)->(Array<bytes31>,felt252,u32)` |
| `IERC1404_EXTEND_ID` | `0xff711fc962f6084c61e8a81115059929cf17dc2fe08b83e577453465d0e7fe` | `0x78a8de7d` | the two ERC-1404 functions, plus<br>`detect_transfer_restriction_from(ContractAddress,ContractAddress,ContractAddress,(u128,u128))->u8` |

Notes:
- `IERC1404_EXTEND_ID` includes the ERC-1404 functions, as CMTAT's `ERC1404EXTEND_INTERFACE_ID` does.
- The ERC-1404 and ERC-1643 ids depend on the `ByteArray` encoding above. CMTAT has no Cairo id to check it against.
- `tests/test_interface_ids.cairo` recomputes every id defined in this crate from its signature strings. The ERC-8343 id is recomputed in `tests/test_pause.cairo`.

### Interfaces per preset

| Interface | Light | Allowlist | Debt | Standard | Snapshot |
|---|:-:|:-:|:-:|:-:|:-:|
| SRC5 | ✓ | ✓ | ✓ | ✓ | ✓ |
| AccessControl | ✓ | ✓ | ✓ | ✓ | ✓ |
| ERC-8343 | ✓ | ✓ | ✓ | ✓ | ✓ |
| ERC-5679 | ✓ | ✓ | ✓ | ✓ | ✓ |
| ERC-7943 | | ✓ | ✓ | ✓ | ✓ |
| ERC-1643 | | ✓ | ✓ | ✓ | ✓ |
| ERC-1404 | | | | ✓ | ✓ |
| IERC1404Extend | | | | ✓ | ✓ |

Each column matches the preset's CMTAT base:
- **Light** follows `CMTATBaseCore`. It has no partial freeze, so it doesn't report ERC-7943.
- **Allowlist** and **Debt** follow `CMTATBaseAccessControl`. CMTAT's Debt base sits below `CMTATBaseERC1404`, so Debt doesn't report ERC-1404.
- **Standard** and **Snapshot** follow `CMTATBaseERC1404`.


---

## Upgrades

Every preset is upgradeable: `upgrade(class_hash)` replaces the class and requires `DEFAULT_ADMIN_ROLE`. Storage carries over unchanged. Every component prefixes its storage names with its module name, so components never collide.

For migrations, the pattern follows Solidity's `Initializable.reinitializer` (see [`src/components/upgrade.cairo`](src/components/upgrade.cairo)):
- **Starting version:** every preset starts at storage version 1, readable through `initialized_version()`.
- **New class:** a new class whose storage needs migrating exposes a `migrate` entry point. That entry point calls `reinitializer(n)` and then moves the data.
- **Rules:** versions only increase, and each version runs once. A reused or lower version reverts with `InvalidInitialization`. Each successful run emits `Initialized(version)`.
- **Sending it:** send `upgrade` and `migrate` in one account multicall, so that no transaction ever runs against unmigrated storage.

`tests/test_upgrade.cairo` upgrades Standard to a V2 mock and runs `migrate`, then checks that every module's storage survived.

---

## Differences from Solidity CMTAT

| Area | Cairo port |
|---|---|
| Meta-transactions | ERC-2771 is not ported. Starknet accounts and paymasters cover this use. |
| Cross-chain, ERC-1363, Permit, HolderList, ERC-7551 module, DebtEngine | Not in release 1. |
| Overloads | Cairo has no overloading, so CMTAT overloads become suffixed names (see [ABI](#abi)). |
| `bytes` data | `Span<felt252>`. |
| `string` | `ByteArray`. |
| Document names | `felt252` short strings, so 31 bytes (one less than `bytes32`). Document hashes are `u256`. |
| Errors | Felt short strings, at most 31 characters. Longer CMTAT names are abbreviated, with the Solidity name noted beside each one in [`src/errors.cairo`](src/errors.cairo). Errors that carry arguments panic with `[NAME, args…]`. |
| Role ids | `selector!("NAME")` rather than `keccak256("NAME")`. |
| Interface ids | SNIP-5 (SRC5) rather than ERC-165 (see above). |
| Upgrades | Starknet `replace_class` under `DEFAULT_ADMIN_ROLE`, rather than proxies. |

---

## Project layout

```
src/
  roles.cairo, errors.cairo   role ids, error names
  interfaces/                 one file per standard or module; constructor structs; SNIP-5 ids
  components/                 one component per CMTAT module; hooks.cairo wires the check order
  presets/                    light, allowlist, standard, debt, snapshot
  mocks/                      single-component tokens, recorder engines, Standard V2 upgrade target
tests/
  test_<component>.cairo      component suites
  test_validation_matrix.cairo   revert and read matrix for every preset
  test_presets.cairo          shared preset suite (ABI surface, roles, upgrades)
  test_preset_events.cairo    exact event sequences per preset
  test_interface_ids.cairo    SNIP-5 ids and registration
  test_fuzz.cairo             freeze and balance arithmetic
  test_upgrade.cairo          upgrade and migrate
scripts/
  deploy.sh                   sncast declare and deploy
  check_sizes.sh              class size check against the Starknet limits
```

CI runs `scarb fmt --check`, `scarb build` (failing on any warning), `snforge test` with coverage, and the size check.

---

## License

[Mozilla Public License 2.0](https://www.mozilla.org/en-US/MPL/2.0/), as for CMTAT.

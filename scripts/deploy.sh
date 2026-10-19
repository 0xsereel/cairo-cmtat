#!/usr/bin/env bash
# Declares CMTAT preset classes and deploys tokens with sncast.
#
#   scripts/deploy.sh declare [PRESET...]   declare classes (default: all presets)
#   scripts/deploy.sh deploy PRESET         deploy one token from the TOKEN_* settings
#   scripts/deploy.sh calldata PRESET       print the constructor calldata (offline)
#
# Presets: light, standard, allowlist, debt, snapshot.
#
# Each class is declared once per network; every token of that preset is then a
# cheap deploy of the same class hash. sncast builds with the `release` profile.
#
# Settings come from the environment (see .env.example):
#   NETWORK        sepolia | mainnet | devnet (default sepolia), or RPC_URL
#   ACCOUNT        sncast account name (or a starkli account file with KEYSTORE)
#   ACCOUNTS_FILE  optional sncast accounts file
#   KEYSTORE       optional keystore, for a starkli account file
#   TOKEN_ADMIN    default admin (required to deploy)
#   TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS (default 0)
#   TOKEN_ID, TERMS_NAME, TERMS_URI, TERMS_HASH (default 0x0), TOKEN_INFORMATION
#   RULE_ENGINE    standard, debt and snapshot only (default 0x0: no engine)
#
# Deployments are appended to deployments/<network>.tsv.

set -euo pipefail

cd "$(dirname "$0")/.."

PRESETS=(light standard allowlist debt snapshot)
NETWORK="${NETWORK:-sepolia}"

die() {
    echo "error: $*" >&2
    exit 1
}

contract_name() {
    case "$1" in
        light) echo CMTATLight ;;
        standard) echo CMTATStandard ;;
        allowlist) echo CMTATAllowlist ;;
        debt) echo CMTATDebt ;;
        snapshot) echo CMTATSnapshot ;;
        *) die "unknown preset '$1' (expected: ${PRESETS[*]})" ;;
    esac
}

# Global sncast flags: account selection. Checked by `main` before use.
account_args() {
    local args=(--account "$ACCOUNT")
    [[ -n "${ACCOUNTS_FILE:-}" ]] && args+=(--accounts-file "$ACCOUNTS_FILE")
    [[ -n "${KEYSTORE:-}" ]] && args+=(--keystore "$KEYSTORE")
    echo "${args[@]}"
}

# Subcommand flags: network selection.
network_args() {
    if [[ -n "${RPC_URL:-}" ]]; then
        echo --url "$RPC_URL"
    else
        echo --network "$NETWORK"
    fi
}

# Last JSON response line of an sncast --json run.
response() {
    grep '"type":"response"' | tail -1
}

# A Cairo string literal. `check_token_settings` has rejected values that
# would need escaping.
cairo_string() {
    printf '"%s"' "$1"
}

require() {
    local name="$1"
    [[ -n "${!name:-}" ]] || die "$name is not set"
}

# Runs in the main shell, so a failure stops the script.
check_token_settings() {
    require TOKEN_ADMIN
    require TOKEN_NAME
    require TOKEN_SYMBOL
    local name value
    for name in TOKEN_NAME TOKEN_SYMBOL TOKEN_ID TERMS_NAME TERMS_URI TOKEN_INFORMATION; do
        value="${!name:-}"
        [[ "$value" != *'"'* && "$value" != *'\'* ]] || die "$name must not contain \" or \\"
    done
}

# Constructor arguments as Cairo expressions (see src/interfaces/constructor.cairo).
constructor_arguments() {
    local preset="$1"
    local erc20
    erc20="ERC20Attributes { name: $(cairo_string "$TOKEN_NAME"), symbol: $(cairo_string "$TOKEN_SYMBOL"), decimals: ${TOKEN_DECIMALS:-0} }"
    if [[ "$preset" == light ]]; then
        echo "$TOKEN_ADMIN, $erc20"
        return
    fi
    local terms extra
    terms="DocumentInfo { name: $(cairo_string "${TERMS_NAME:-}"), uri: $(cairo_string "${TERMS_URI:-}"), document_hash: ${TERMS_HASH:-0x0} }"
    extra="ExtraInformationAttributes { token_id: $(cairo_string "${TOKEN_ID:-}"), terms: $terms, information: $(cairo_string "${TOKEN_INFORMATION:-}") }"
    case "$preset" in
        allowlist) echo "$TOKEN_ADMIN, $erc20, $extra" ;;
        *) echo "$TOKEN_ADMIN, $erc20, $extra, ${RULE_ENGINE:-0x0}" ;;
    esac
}

# Serializes the constructor arguments against the release ABI, offline.
calldata() {
    local preset="$1" name abi arguments out
    name="$(contract_name "$preset")"
    arguments="$(constructor_arguments "$preset")"
    scarb --release build >/dev/null
    abi="$(mktemp)"
    jq '.abi' "target/release/cairo_cmtat_${name}.contract_class.json" >"$abi"
    out="$(sncast --json utils serialize --abi-file "$abi" --function constructor \
        --arguments "$arguments")" || true
    rm -f "$abi"
    echo "$out" | response | jq -r '.calldata | join(" ")' | grep . || {
        echo "$out" >&2
        die "cannot serialize constructor arguments for $preset"
    }
}

class_hash() {
    sncast --json utils class-hash --contract-name "$(contract_name "$1")" |
        response | jq -r '.class_hash'
}

declare_preset() {
    local preset="$1" name hash out
    name="$(contract_name "$preset")"
    hash="$(class_hash "$preset")"
    echo "$preset ($name): $hash"
    # shellcheck disable=SC2046
    if out="$(sncast --json --wait $(account_args) declare --contract-name "$name" \
        $(network_args) 2>&1)"; then
        echo "  declared, tx $(echo "$out" | response | jq -r '.transaction_hash')"
    elif grep -qi "already declared" <<<"$out"; then
        echo "  already declared"
    else
        echo "$out" >&2
        die "declare failed for $preset"
    fi
}

deploy_preset() {
    local preset="$1" hash args out address tx
    hash="$(class_hash "$preset")"
    args="$(calldata "$preset")"
    echo "Deploying $preset ($hash) on $NETWORK"
    echo "  arguments: $(constructor_arguments "$preset")"
    # shellcheck disable=SC2046,SC2086
    out="$(sncast --json --wait $(account_args) deploy --class-hash "$hash" \
        --constructor-calldata $args $(network_args))" || die "deploy failed"
    address="$(echo "$out" | response | jq -r '.contract_address')"
    tx="$(echo "$out" | response | jq -r '.transaction_hash')"
    echo "  address: $address"
    echo "  tx: $tx"
    mkdir -p deployments
    local log="deployments/${NETWORK}.tsv"
    [[ -f "$log" ]] || printf 'date\tpreset\tsymbol\tclass_hash\taddress\ttx\n' >"$log"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$preset" \
        "$TOKEN_SYMBOL" "$hash" "$address" "$tx" >>"$log"
}

usage() {
    sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
}

main() {
    [[ $# -ge 1 ]] || usage
    local command="$1"
    shift
    case "$command" in
        declare)
            require ACCOUNT
            if [[ $# -eq 0 ]]; then set -- "${PRESETS[@]}"; fi
            for preset in "$@"; do declare_preset "$preset"; done
            ;;
        deploy)
            [[ $# -eq 1 ]] || usage
            contract_name "$1" >/dev/null
            require ACCOUNT
            check_token_settings
            deploy_preset "$1"
            ;;
        calldata)
            [[ $# -eq 1 ]] || usage
            contract_name "$1" >/dev/null
            check_token_settings
            calldata "$1"
            ;;
        *) usage ;;
    esac
}

main "$@"

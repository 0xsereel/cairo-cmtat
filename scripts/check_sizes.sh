#!/usr/bin/env bash
# Description: report Sierra and CASM sizes for every contract class in the
# release build, and fail if any exceeds a margin of Starknet's class limits.
#
# Usage: scripts/check_sizes.sh [margin_percent]   (default 90)
set -euo pipefail

MARGIN="${1:-90}"
# Starknet limits: Sierra class size in bytes, CASM bytecode length in felts.
MAX_SIERRA_BYTES=4089446
MAX_CASM_FELTS=81920

cd "$(dirname "$0")/.."
scarb --release build >/dev/null

python3 - "$MARGIN" "$MAX_SIERRA_BYTES" "$MAX_CASM_FELTS" <<'EOF'
import glob, json, os, sys

margin, max_sierra, max_casm = (int(a) for a in sys.argv[1:4])
fail = False
print(f"{'contract':<40} {'sierra bytes':>14} {'%':>5} {'casm felts':>11} {'%':>5}")
for casm_path in sorted(glob.glob("target/release/*.compiled_contract_class.json")):
    sierra_path = casm_path.replace(".compiled_contract_class.", ".contract_class.")
    name = os.path.basename(sierra_path).removesuffix(".contract_class.json")
    sierra = os.path.getsize(sierra_path)
    casm = len(json.load(open(casm_path))["bytecode"])
    sp, cp = 100 * sierra / max_sierra, 100 * casm / max_casm
    over = sp > margin or cp > margin
    fail |= over
    print(f"{name:<40} {sierra:>14} {sp:>5.1f} {casm:>11} {cp:>5.1f}{'  OVER' if over else ''}")
if fail:
    sys.exit(f"error: a contract class exceeds {margin}% of a Starknet size limit")
EOF

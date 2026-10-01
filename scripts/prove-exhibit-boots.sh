#!/bin/bash
# prove-exhibit-boots.sh — standalone proof of the suite's two bt-exhibit
# provenance checks, for when the suite cannot run (trial open): an exhibit's
# provenance names the boots its command selects by 32-hex id, apart from the
# capture boot; a command that names no boot says so.
#
#   scripts/prove-exhibit-boots.sh
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
EXR=$(mktemp -d)
mkdir -p "$EXR/evidence/exhibits" "$EXR/tools"
# bt-exhibit refuses to write without the sanitiser beside it in the checkout
cp tools/sanitize-logs.sh "$EXR/tools/"
pass=0; fail=0
ok()  { echo "  ✓ $*"; pass=$((pass+1)); }
bad() { echo "  ✗ $*"; fail=$((fail+1)); }
BT_REPO="$EXR" tools/bt-exhibit new probe-one --claim "The probe emits its marker." --cmd 'echo marker' >/dev/null
BT_REPO="$EXR" tools/bt-exhibit new probe-boots --claim "Two boots are named." \
    --cmd 'echo 0123456789abcdef0123456789abcdef fedcba9876543210fedcba9876543210' >/dev/null
one=$(cat "$EXR/evidence/exhibits/001-probe-one.md" 2>/dev/null)
two=$(cat "$EXR/evidence/exhibits/002-probe-boots.md" 2>/dev/null)
[[ "$two" == *'| capture boot id | `'* && "$two" == *'| evidence boot ids | `01234567, fedcba98` |'* ]] \
    && ok "bt-exhibit names the evidence boots from the command, apart from the capture boot" \
    || { bad "evidence boots not separated from the capture boot"; grep -n "boot" <<<"$two"; }
[[ "$one" == *'| evidence boot ids | none named by the command'* ]] \
    && ok "an exhibit whose command names no boot says so in its provenance" \
    || { bad "no-boot exhibit did not say so"; grep -n "boot" <<<"$one"; }
rm -rf "$EXR"
echo "pass=$pass fail=$fail"; (( fail == 0 ))

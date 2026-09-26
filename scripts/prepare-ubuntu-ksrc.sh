#!/bin/bash
# prepare-ubuntu-ksrc.sh — Ubuntu's own Bluetooth source for one linux-hwe-7.0
# release: a sparse worktree of cache/linux at v7.0 (drivers/bluetooth,
# include/net/bluetooth, net/bluetooth) with the Ubuntu source diff for those
# paths applied. The tree a self-built bluetooth.ko or btusb.ko must come from
# to match the running kernel — vanilla v7.0 would be wrong (the Ubuntu delta
# touches btusb.c, mgmt.c and ~25 other Bluetooth files).
#
#   scripts/prepare-ubuntu-ksrc.sh <package-version>
#   e.g. scripts/prepare-ubuntu-ksrc.sh 7.0.0-34.34~24.04.1   -> cache/ubuntu-7.0.0-34
#
# Needs cache/ubuntu-src/linux-hwe-7.0_<version>.{dsc,diff.gz} (from
# archive.ubuntu.com/ubuntu/pool/main/l/linux-hwe-7.0/). Refuses if the
# diff.gz does not match the SHA-256 in the .dsc. The .dsc signature is not
# checked (the kernel team's key is not in this keyring): record that.
#
# WHY A SCRIPT. The -31 tree (2026-09-23) was made by hand; the kernel was
# updated to -34 two days later, and a module built from -31 source would not
# match it.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VER="${1:?usage: prepare-ubuntu-ksrc.sh <package-version, e.g. 7.0.0-34.34~24.04.1>}"
[[ "$VER" =~ ^(7\.0\.0-[0-9]+)\. ]] || { echo "unexpected version form: $VER" >&2; exit 2; }
ABI="${BASH_REMATCH[1]}"
SRCDIR="$HERE/cache/ubuntu-src"
DSC="$SRCDIR/linux-hwe-7.0_${VER}.dsc"
DIFF="$SRCDIR/linux-hwe-7.0_${VER}.diff.gz"
TREE="$HERE/cache/ubuntu-${ABI}"
BASE="$HERE/cache/linux"

[[ -r "$DSC" && -r "$DIFF" ]] || { echo "missing $DSC or $DIFF" >&2; exit 2; }
want=$(awk '/^Checksums-Sha256:/ {f=1; next} f && /diff\.gz$/ {print $1; exit}' "$DSC")
have=$(sha256sum "$DIFF" | cut -d' ' -f1)
[[ -n "$want" && "$want" == "$have" ]] || { echo "✗ diff.gz sha256 $have does not match the .dsc ($want)" >&2; exit 1; }
echo "✓ diff.gz sha256 matches the .dsc (signature of the .dsc NOT checked)"

if [[ -e "$TREE" ]]; then echo "exists: $TREE — remove it first to rebuild" >&2; exit 2; fi
git -C "$BASE" worktree add -q --no-checkout "$TREE" v7.0 || exit 2
git -C "$TREE" sparse-checkout set drivers/bluetooth include/net/bluetooth net/bluetooth || exit 2
git -C "$TREE" checkout -q v7.0 || exit 2

# The Ubuntu diff's paths carry one leading directory; keep only the three
# Bluetooth paths (the rest — debian/, other drivers — is not checked out).
zcat "$DIFF" | git -C "$TREE" apply -p1 \
	--include='drivers/bluetooth/*' --include='include/net/bluetooth/*' --include='net/bluetooth/*' \
	--exclude='*' --whitespace=nowarn || { echo "✗ the Ubuntu diff did not apply to v7.0" >&2; exit 1; }
echo "tree: $TREE  (v7.0 + linux-hwe-7.0 $VER, Bluetooth paths)"
git -C "$TREE" status --short | awk '{print "  " $0}'

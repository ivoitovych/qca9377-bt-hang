#!/bin/bash
# build-bluetooth-fulltree.sh — the real compile check for a kernel patch at
# another tree's tip: a FULL checkout of that tip (a worktree of cache/linux,
# blobs fetched on demand), `make defconfig` + Bluetooth as a module,
# `make modules_prepare`, then `make M=net/bluetooth` unpatched (control) and
# patched, with -Werror on the patched file's directory. No install, no load.
#
#   scripts/build-bluetooth-fulltree.sh <ref> <name> <patch>
#   e.g. scripts/build-bluetooth-fulltree.sh stable/linux-6.1.y full-6.1.y tmp/kernel-0001.patch
#
# Writes: cache/<name>/ (the worktree, ignored) and its build output in place.
# Needs bison, flex, libelf-dev, libssl-dev (installed 2026-09-22). Exit 0 when
# both builds succeed.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REF="${1:?usage: build-bluetooth-fulltree.sh <ref> <name> <patch>}"
NAME="${2:?usage: build-bluetooth-fulltree.sh <ref> <name> <patch>}"
PATCH="${3:?usage: build-bluetooth-fulltree.sh <ref> <name> <patch>}"
[[ -r "$PATCH" ]] || { echo "cannot read $PATCH" >&2; exit 2; }
PATCH="$(readlink -f "$PATCH")"
BASE="$HERE/cache/linux"
TREE="$HERE/cache/$NAME"
J=$(nproc)

if [[ ! -d "$TREE" ]]; then
	git -C "$BASE" worktree add --no-checkout "$TREE" "$REF" || exit 2
	git -C "$TREE" sparse-checkout disable
	git -C "$TREE" checkout -q "$REF" || exit 2
fi
echo "tree: $(git -C "$TREE" log -1 --format='%h %cs %s' | cut -c1-90)"
git -C "$TREE" checkout -q -- net/bluetooth    # always start from the tree's own file

cd "$TREE" || exit 2
if [[ ! -f .config ]]; then
	make -s defconfig >/dev/null || exit 2
	scripts/config --module BT --module BT_RFCOMM --module BT_BNEP --module BT_HIDP \
	               --enable BT_LE --enable BT_BREDR --enable BT_MSFTEXT --enable BT_AOSPEXT >/dev/null
	make -s olddefconfig >/dev/null || exit 2
fi
echo "── modules_prepare"
make -s -j"$J" modules_prepare 2>&1 | grep -vE "^\s*$" | tail -3
rc=0
for v in unpatched patched; do
	git checkout -q -- net/bluetooth
	if [[ $v == patched ]]; then
		patch -p1 < "$PATCH" | grep -E "Hunk|FAILED"
	fi
	make -s -j"$J" M=net/bluetooth clean >/dev/null 2>&1
	# KBUILD_MODPOST_WARN=1: without a vmlinux build there is no Module.symvers
	# for core symbols; modpost then errors on newer trees (6.1 only warned).
	# The compile of every object is what this check is for.
	if make -j"$J" M=net/bluetooth KCFLAGS=-Werror KBUILD_MODPOST_WARN=1 modules > "make-$v.log" 2>&1; then
		printf '%-10s make rc=0  %s\n' "$v" "$(ls net/bluetooth/bluetooth.ko && stat -c '%s bytes' net/bluetooth/bluetooth.ko)"
	else
		printf '%-10s make FAILED — %s\n' "$v" "$(grep -m1 -E 'error' "make-$v.log")"
		rc=1
	fi
done
git checkout -q -- net/bluetooth
exit $rc

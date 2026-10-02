#!/bin/bash
# build-btusb-stable-matrix.sh — apply a btusb patch to each stable line and
# BUILD btusb there, not only dry-run it: a full checkout of each tip (worktree
# of cache/linux, blobs on demand), defconfig + Bluetooth and btusb as modules,
# modules_prepare, then `make M=drivers/bluetooth` unpatched (control) and
# patched. -Werror where the tree's own unpatched build tolerates it. No
# install, no load; the laptop's kernel is untouched.
#
#   scripts/build-btusb-stable-matrix.sh <patch> [<stable-branch>…]
#   default branches: the lines live on kernel.org on 2026-10-02
#
# Per branch: tip, how the patch applied (offset/fuzz), whether the entry is in
# the compiled source, unpatched and patched make results. Logs under
# tmp/btusb-matrix/. Exit 0 when every patched build succeeds.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH="${1:?usage: build-btusb-stable-matrix.sh <patch> [<stable-branch>…]}"; shift
[[ -r "$PATCH" ]] || { echo "cannot read $PATCH" >&2; exit 2; }
PATCH="$(readlink -f "$PATCH")"
BRANCHES=("$@")
(( ${#BRANCHES[@]} )) || BRANCHES=(stable/linux-7.2.y stable/linux-6.18.y stable/linux-6.12.y stable/linux-6.6.y stable/linux-6.1.y stable/linux-5.15.y stable/linux-5.10.y)
BASE="$HERE/cache/linux"
LOGS="$HERE/tmp/btusb-matrix"; mkdir -p "$LOGS"
J=$(nproc)
rc=0
printf '%-22s %-14s %-28s %-10s %-12s %s\n' "branch" "tip" "apply" "entry" "unpatched" "patched"
for b in "${BRANCHES[@]}"; do
	name="stable-${b#stable/linux-}"; TREE="$HERE/cache/$name"; log="$LOGS/$name.log"
	: > "$log"
	if [[ ! -d "$TREE" ]]; then
		git -C "$BASE" worktree add --no-checkout "$TREE" "$b" >>"$log" 2>&1 || { printf '%-22s worktree FAILED\n' "$b"; rc=1; continue; }
		git -C "$TREE" sparse-checkout disable >>"$log" 2>&1
		git -C "$TREE" checkout -q "$b" >>"$log" 2>&1 || { printf '%-22s checkout FAILED\n' "$b"; rc=1; continue; }
	fi
	tip=$(git -C "$TREE" log -1 --format=%h)
	git -C "$TREE" checkout -q -- drivers/bluetooth
	(
		cd "$TREE" || exit 2
		if [[ ! -f .config ]]; then
			make -s defconfig >/dev/null 2>&1 || exit 2
			scripts/config --module BT --module BT_HCIBTUSB --enable BT_LE --enable BT_BREDR \
			               --enable BT_HCIBTUSB_BCM --enable BT_HCIBTUSB_RTL --enable BT_HCIBTUSB_MTK >/dev/null 2>&1
			make -s olddefconfig >/dev/null 2>&1 || exit 2
		fi
		make -s -j"$J" modules_prepare >>"$log" 2>&1 || exit 3
	) || { printf '%-22s %-14s prepare FAILED (see %s)\n' "$b" "$tip" "$log"; rc=1; continue; }
	werror=KCFLAGS=-Werror
	build() {   # build <label> → "rc=0 <size>" or "FAILED"; drops -Werror if the control cannot take it
		local label="$1"
		make -s -C "$TREE" -j"$J" M=drivers/bluetooth clean >/dev/null 2>&1
		if make -C "$TREE" -j"$J" M=drivers/bluetooth $werror KBUILD_MODPOST_WARN=1 modules >>"$log" 2>&1; then
			echo "rc=0 $(stat -c %s "$TREE/drivers/bluetooth/btusb.ko" 2>/dev/null)B"
		elif [[ $label == unpatched && -n $werror ]]; then
			werror=""
			echo "(control fails -Werror; retrying without)" >>"$log"
			build "$label"
		else
			echo "FAILED"
		fi
	}
	un=$(build unpatched)
	git -C "$TREE" checkout -q -- drivers/bluetooth
	apply=$(patch -d "$TREE" -p1 --forward < "$PATCH" 2>&1 | grep -oE 'offset [-0-9]+ lines?|fuzz [0-9]+|FAILED|malformed' | tr '\n' ' ')
	[[ -n "$apply" ]] || apply="clean"
	entry=$(grep -c "0x13d3, 0x3503" "$TREE/drivers/bluetooth/btusb.c")
	pa=$(build patched)
	[[ "$pa" == rc=0* && "$entry" == 1 && "$apply" != *FAILED* ]] || rc=1
	printf '%-22s %-14s %-28s %-10s %-12s %s%s\n' "$b" "$tip" "$apply" "x$entry" "$un" "$pa" "${werror:+  (-Werror)}"
	git -C "$TREE" checkout -q -- drivers/bluetooth
done
exit $rc

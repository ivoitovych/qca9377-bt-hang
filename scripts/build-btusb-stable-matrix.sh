#!/bin/bash
# build-btusb-stable-matrix.sh — does a mainline commit CHERRY-PICK and BUILD on
# each stable line? The check a backport request rests on: not `patch --dry-run`
# (text), not `patch -p1` (fuzz), but `git cherry-pick` of the commit itself —
# what the stable team's pickup is — on a full checkout of each line's tip,
# fetched this minute, followed by `make M=drivers/bluetooth` unpatched (control)
# and picked, with -Werror where the tree's own control build takes it. No
# install, no load; the laptop's kernel is untouched.
#
#   scripts/build-btusb-stable-matrix.sh <commit> [<stable-branch>…]
#   default branches: the lines live on kernel.org on 2026-10-02
#
# Per branch: tip after the fetch, cherry-pick result (OK / CONFLICT), whether the
# entry is in the picked source, unpatched and picked make results. Each worktree
# (cache/stable-<ver>/) is reset to the fresh tip every run, so a rerun never
# rebuilds yesterday's tip. Logs under tmp/btusb-matrix/. Exit 0 when every
# cherry-pick and every picked build succeeds.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMIT="${1:?usage: build-btusb-stable-matrix.sh <commit> [<stable-branch>…]}"; shift
BRANCHES=("$@")
(( ${#BRANCHES[@]} )) || BRANCHES=(stable/linux-7.2.y stable/linux-6.18.y stable/linux-6.12.y stable/linux-6.6.y stable/linux-6.1.y stable/linux-5.15.y stable/linux-5.10.y)
BASE="$HERE/cache/linux"
LOGS="$HERE/tmp/btusb-matrix"; mkdir -p "$LOGS"
J=$(nproc)
rc=0
echo "fetching stable…"
git -C "$BASE" fetch -q stable 2>/dev/null || { echo "fetch failed" >&2; exit 2; }
echo "commit: $(git -C "$BASE" log -1 --format='%h %s' "$COMMIT")"
printf '%-22s %-14s %-12s %-7s %-14s %s\n' "branch" "tip" "cherry-pick" "entry" "unpatched" "picked"
for b in "${BRANCHES[@]}"; do
	name="stable-${b#stable/linux-}"; TREE="$HERE/cache/$name"; log="$LOGS/$name.log"
	: > "$log"
	if [[ ! -d "$TREE" ]]; then
		git -C "$BASE" worktree add --no-checkout --detach "$TREE" "$b" >>"$log" 2>&1 || { printf '%-22s worktree FAILED\n' "$b"; rc=1; continue; }
		git -C "$TREE" sparse-checkout disable >>"$log" 2>&1
	fi
	# Always the fetched tip, never whatever the worktree held last time.
	git -C "$TREE" cherry-pick --abort >/dev/null 2>&1 || true
	git -C "$TREE" checkout -q --detach "$b" >>"$log" 2>&1 || { printf '%-22s checkout FAILED\n' "$b"; rc=1; continue; }
	git -C "$TREE" reset -q --hard "$b" >>"$log" 2>&1
	tip=$(git -C "$TREE" log -1 --format=%h)
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
	if git -C "$TREE" cherry-pick --no-commit "$COMMIT" >>"$log" 2>&1; then
		pick="OK"
	else
		pick="CONFLICT"
		git -C "$TREE" diff --name-only --diff-filter=U >>"$log" 2>&1
	fi
	entry=$(grep -c "0x13d3, 0x3503" "$TREE/drivers/bluetooth/btusb.c")
	if [[ $pick == OK ]]; then pa=$(build picked); else pa="(not built)"; fi
	[[ "$pick" == OK && "$pa" == rc=0* && "$entry" == 1 ]] || rc=1
	printf '%-22s %-14s %-12s %-7s %-14s %s%s\n' "$b" "$tip" "$pick" "x$entry" "$un" "$pa" "${werror:+  (-Werror)}"
	git -C "$TREE" cherry-pick --abort >/dev/null 2>&1 || true
	git -C "$TREE" reset -q --hard "$b" >>"$log" 2>&1
done
exit $rc

#!/bin/bash
# kernel-preflight.sh — the kernel submission checklist, run INSIDE a full
# kernel worktree whose HEAD is the patch commit (so checkpatch can resolve
# Fixes: hashes, which it cannot from outside a tree):
#
#   1. scripts/checkpatch.pl --strict -g HEAD
#   2. make M=net/bluetooth W=1   (extra warnings)        -Werror on the objects
#   3. make M=net/bluetooth C=2   (sparse on every file)  — sparse's findings
#      in mgmt.c are compared with HEAD~1, so only NEW ones count against the patch
#
#   scripts/kernel-preflight.sh <full-kernel-worktree>
#
# Needs a tree prepared by scripts/build-bluetooth-fulltree.sh (.config,
# modules_prepare) and `sparse` installed. Writes build output in the tree only.
set -uo pipefail
TREE="${1:-$(dirname "${BASH_SOURCE[0]}")/../cache/full-bt-next}"   # default: the bluetooth-next worktree
BT_SPARSE="${BT_SPARSE:-$(dirname "${BASH_SOURCE[0]}")/../cache/sparse/sparse}"   # default: the current sparse built there
[[ -x "$BT_SPARSE" ]] || BT_SPARSE=sparse
cd "$TREE" || exit 2
J=$(nproc)
rc=0
echo "tree: $(git log -1 --format='%h %s' | cut -c1-90)"
echo "base: $(git log -1 --format='%h %s' HEAD~1 | cut -c1-90)"

echo "── checkpatch --strict -g HEAD"
scripts/checkpatch.pl --strict -g HEAD || rc=1

echo "── W=1 build of net/bluetooth"
make -s -j"$J" M=net/bluetooth clean >/dev/null 2>&1
if make -j"$J" M=net/bluetooth W=1 KCFLAGS=-Werror KBUILD_MODPOST_WARN=1 modules > make-w1.log 2>&1; then
	echo "   W=1 -Werror: clean"
else
	echo "   W=1 -Werror: FAILED"; grep -m5 -E "error|warning" make-w1.log; rc=1
fi

SPARSE="${BT_SPARSE:-sparse}"   # e.g. cache/sparse/sparse — distro 0.6.4 is too old for 7.x
sparse_mgmt() {   # sparse findings for mgmt.c at the current checkout
	touch net/bluetooth/mgmt.c
	make -j"$J" M=net/bluetooth C=1 CHECK="$SPARSE" KBUILD_MODPOST_WARN=1 modules > make-c1.log 2>&1
	grep -E 'mgmt\.c:[0-9]+:[0-9]+: (warning|error)' make-c1.log \
		| sed -E 's/:[0-9]+:[0-9]+:/:/' | sort
}
echo "── sparse (C=1) on mgmt.c, patched vs base"
after=$(sparse_mgmt)
# POSITIVE CONTROL. On 2026-09-23 this reported "0 findings" while the kernel
# had refused to run sparse at all ("not available or not up to date"). A zero
# counts only if the CHECK step for mgmt.c is in the log.
if grep -q "sparse is not available or not up to date" make-c1.log || ! grep -qE '^\s*CHECK\s+.*mgmt\.c' make-c1.log; then
	echo "   sparse DID NOT RUN on mgmt.c ($(grep -m1 -E 'sparse|CHECK' make-c1.log)) — no result"
	exit 1
fi
git checkout -q HEAD~1 -- net/bluetooth/mgmt.c
before=$(sparse_mgmt)
git checkout -q HEAD -- net/bluetooth/mgmt.c
new=$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | grep -v '^$')
echo "   findings in mgmt.c: base $(printf '%s\n' "$before" | grep -c .), patched $(printf '%s\n' "$after" | grep -c .)"
if [[ -n "$new" ]]; then echo "   NEW with the patch:"; printf '      %s\n' "$new"; rc=1
else echo "   no new sparse finding introduced by the patch"; fi

# Recipients, from the tree itself (get_maintainer.pl refuses outside a tree).
# ⚠️ `Cc: stable@vger.kernel.org` in the patch body is a TAG, "NOT an email
# recipient" (Documentation/process/submitting-patches.rst) — send with
# `git send-email --suppress-cc=bodycc` so it is not mailed to the stable list.
echo "── recipients: scripts/get_maintainer.pl on the patch commit"
git format-patch -1 --stdout HEAD > .preflight.patch
scripts/get_maintainer.pl --no-rolestats .preflight.patch
scripts/get_maintainer.pl .preflight.patch | sed 's/^/   role: /'
rm -f .preflight.patch

exit $rc

#!/bin/bash
# compile-mgmt-at.sh — compile ONE file, net/bluetooth/mgmt.c, from a sparse
# kernel checkout at another tip (a worktree of cache/linux), against the running
# kernel's build system, with that tree's include/ placed first and -Werror.
# Unpatched (control) and patched, in that order.
#
#   scripts/compile-mgmt-at.sh <sparse-tree> <patch>
#
# Why one file: a tree months newer or older than the running kernel does not
# build net/bluetooth whole against these headers (bluetooth-next: a socket API
# changed; 6.1.y / 6.12.y: core headers diverged) — that needs a full tree with
# `make modules_prepare`, which this machine lacks the packages for. The file the
# patch touches is what the hunk must compile in; this proves that much and no
# more. Writes only under tmp/bt-obj/. Exit 0 when both compiles succeed.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TREE="${1:?usage: compile-mgmt-at.sh <sparse-tree> <patch>}"
PATCH="${2:?usage: compile-mgmt-at.sh <sparse-tree> <patch>}"
KBUILD="/lib/modules/$(uname -r)/build"
[[ -f "$TREE/net/bluetooth/mgmt.c" ]] || { echo "no net/bluetooth/mgmt.c under $TREE" >&2; exit 2; }
[[ -r "$PATCH" ]] || { echo "cannot read $PATCH" >&2; exit 2; }
echo "tree: $(git -C "$TREE" log -1 --format='%h %cs %s' | cut -c1-90)"
rc=0
for v in unpatched patched; do
	OUT="$HERE/tmp/bt-obj"
	rm -rf "$OUT"; mkdir -p "$OUT/net"
	cp -r "$TREE/net/bluetooth" "$OUT/net/bluetooth"
	if [[ $v == patched ]]; then
		patch -p1 -d "$OUT" < "$PATCH" | grep -E "Hunk|FAILED" || { echo "patch did not apply" >&2; exit 1; }
	fi
	log="$OUT/make-$v.log"
	make -C "$KBUILD" M="$OUT/net/bluetooth" \
	     NOSTDINC_FLAGS="-nostdinc -I$TREE/include" KCFLAGS="-Werror" mgmt.o >"$log" 2>&1
	mrc=$?
	size=$(stat -c %s "$OUT/net/bluetooth/mgmt.o" 2>/dev/null || echo "-")
	printf '%-10s make rc=%s  mgmt.o=%s bytes\n' "$v" "$mrc" "$size"
	(( mrc == 0 )) || { grep -E "error" "$log" | head -3; rc=1; }
done
exit $rc

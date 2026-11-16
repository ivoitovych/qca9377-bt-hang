#!/bin/bash
# checkpatch-check.sh — run checkpatch on both patches UNDER BLUEZ'S OWN
# .checkpatch.conf, which checkpatch only reads from the current directory.
#
#   patches/bluez/checkpatch-check.sh <bluez-tree> [checkpatch.pl]
#
# BlueZ's config ignores MISSING_SIGN_OFF (BlueZ forbids Signed-off-by) and
# sets its own line rules; running checkpatch anywhere else applies the kernel's
# defaults and reports the wrong things. Output is checkpatch's own, per patch,
# followed by one summary line per patch. Exit 1 if any patch has an ERROR.
#
# checkpatch.pl is not shipped with BlueZ; the kernel headers package carries
# one under /usr/src/linux-headers-*/scripts/. Pass a path to override.
set -uo pipefail
TREE="${1:?usage: checkpatch-check.sh <bluez-tree> [checkpatch.pl]}"
CP="${2:-}"
if [[ -z "$CP" ]]; then
    for c in /usr/src/linux-headers-*/scripts/checkpatch.pl; do
        [[ -f "$c" ]] && CP="$c"
    done
fi
[[ -n "$CP" && -f "$CP" ]] || { echo "no checkpatch.pl found; pass one" >&2; exit 2; }
[[ -f "$TREE/.checkpatch.conf" ]] || { echo "no .checkpatch.conf in $TREE" >&2; exit 2; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# BT_PATCH_DIR: check another directory of patches (e.g. patches/bluez/v2)
# with the same rules; default is the directory this script lives in.
HERE="${BT_PATCH_DIR:-$HERE}"
# Made absolute BEFORE the cd below: a relative BT_PATCH_DIR (the form the README
# documents) would otherwise be looked up inside the BlueZ tree.
HERE="$(cd "$HERE" 2>/dev/null && pwd)" || { echo "no such patch directory: ${BT_PATCH_DIR:-$HERE}" >&2; exit 2; }
CP="$(realpath -- "$CP")"
cd "$TREE" || exit 2
rc=0
n_patches=0
for p in "$HERE"/0*.patch; do
    [[ -f "$p" ]] || continue
    n_patches=$((n_patches + 1))
    echo "── $(basename "$p")"
    # No --strict: BlueZ's .checkpatch.conf does not set it, so a maintainer
    # running checkpatch sees exactly this and no CHECK: lines.
    out=$(perl "$CP" "$p" 2>&1)
    echo "$out" | sed 's/^/   /'
    # checkpatch always ends a run with a "total: N errors, ..." line (its own
    # exit status is non-zero for findings, so it cannot tell "ran" from
    # "did not run"). Without that line it did not run: say so, never "0 error(s)".
    if ! grep -q '^total: ' <<<"$out"; then
        printf '   %s: NOT RUN (no "total:" line from checkpatch)\n' "$(basename "$p")"
        rc=2
        continue
    fi
    errors=$(grep -c '^ERROR:' <<<"$out" || true)
    warns=$(grep -c '^WARNING:' <<<"$out" || true)
    checks=$(grep -c '^CHECK:' <<<"$out" || true)
    printf '   %s: %s error(s), %s warning(s), %s check(s)\n' "$(basename "$p")" "$errors" "$warns" "$checks"
    (( errors > 0 && rc == 0 )) && rc=1
done
(( n_patches > 0 )) || { echo "no 0*.patch file in $HERE: nothing was checked" >&2; exit 2; }
exit $rc

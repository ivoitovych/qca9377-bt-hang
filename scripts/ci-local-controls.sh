#!/bin/bash
# ci-local-controls.sh — the positive controls for scripts/ci-local.sh: a
# check that cannot be seen to fail proves nothing (BRIEF §8a). Two scratch
# patches are written from the BlueZ base, each carrying one deliberate
# defect, and ci-local.sh must report each as NEW:
#
#   control-checkpatch-error   a line indented with spaces and a space-before-
#                              parenthesis in emulator/btdev.c; checkpatch
#                              reports ERROR: on it, so CheckPatch must be NEW
#   control-vla                a used variable length array in btdev_create();
#                              smatch reports "Variable length array is used."
#                              on a line that is not in the base, so CheckSmatch
#                              must be NEW (the base's btdev.c:479 line stays
#                              PRE-EXISTING in the same run)
#
#   scripts/ci-local-controls.sh [--tree DIR] [--base REF] [--out DIR] [--skip-smatch]
#
# The scratch patches are left under <out>/ (default tmp/ci-local/controls-<UTC
# stamp>/) with the two ci-local.sh runs; the exit status is 0 only if every
# expected NEW was reported. --skip-smatch runs only the checkpatch control
# (the smatch control builds BlueZ twice unless the base side is cached).
set -uo pipefail
export LC_ALL=C
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TREE="$REPO/cache/bluez"
BASE=origin/master
OUT=""
SKIP_SMATCH=0
while (( $# )); do
	case "$1" in
	--tree) TREE="$2"; shift ;;
	--base) BASE="$2"; shift ;;
	--out) OUT="$2"; shift ;;
	--skip-smatch) SKIP_SMATCH=1 ;;
	-h|--help) sed -n '2,24p' "$0"; exit 0 ;;
	*) echo "ci-local-controls: unknown argument $1" >&2; exit 2 ;;
	esac
	shift
done
[[ -z "$OUT" ]] && OUT="$REPO/tmp/ci-local/controls-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUT" || exit 2
OUT="$(readlink -f "$OUT")"
BASE_SHA="$(git -C "$TREE" rev-parse --verify "$BASE^{commit}")" || exit 2
echo "base $BASE_SHA $(git -C "$TREE" log -1 --format='%cs %s' "$BASE_SHA")"

W="$OUT/scratch-worktree"
git -C "$TREE" worktree add --quiet --detach "$W" "$BASE_SHA" || exit 2
trap 'git -C "$TREE" worktree remove --force "$W" 2>/dev/null' EXIT
AUTHOR=(-c user.name="scratch control" -c user.email="scratch@example.com")

# Control 1: checkpatch ERROR (space-indented line, "if(" without a space).
python3 -I - "$W/emulator/btdev.c" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old = "void btdev_destroy(struct btdev *btdev)\n{\n\tif (!btdev)\n\t\treturn;\n"
new = "void btdev_destroy(struct btdev *btdev)\n{\n        if(!btdev)\n\t\treturn;\n"
assert s.count(old) == 1, "anchor for control 1 not found once"
open(p, "w").write(s.replace(old, new))
PY
git -C "$W" "${AUTHOR[@]}" commit --quiet -a -m "emulator: scratch control with a checkpatch error" -m "Deliberate: space indentation and if( without a space. Never to be sent."
git -C "$W" format-patch --quiet --subject-prefix="PATCH BlueZ" -1 -o "$OUT" --start-number 1 HEAD
mv "$OUT"/0001-*.patch "$OUT/control-checkpatch-error.patch"
git -C "$W" reset --quiet --hard "$BASE_SHA"

# Control 2: a used VLA in btdev_create().
python3 -I - "$W/emulator/btdev.c" <<'PY'
import sys, re
p = sys.argv[1]; s = open(p).read()
# The declaration goes with the other declarations and the use after the first
# statement: BlueZ builds with -Werror and -Wdeclaration-after-statement.
old = "\tstruct btdev *btdev;\n\tint index;\n\n\tbtdev = malloc(sizeof(*btdev));\n\tif (!btdev)\n\t\treturn NULL;\n\n\tmemset(btdev, 0, sizeof(*btdev));\n"
new = "\tstruct btdev *btdev;\n\tint index;\n\tuint8_t scratch[id + 1];\n\n\tbtdev = malloc(sizeof(*btdev));\n\tif (!btdev)\n\t\treturn NULL;\n\n\tmemset(btdev, 0, sizeof(*btdev));\n\tmemset(scratch, 0, sizeof(scratch));\n"
assert s.count(old) == 1, "anchor for control 2 not found once"
open(p, "w").write(s.replace(old, new))
PY
git -C "$W" "${AUTHOR[@]}" commit --quiet -a -m "emulator: scratch control with a variable length array" -m "Deliberate: a used VLA in btdev_create(). Never to be sent."
git -C "$W" format-patch --quiet --subject-prefix="PATCH BlueZ" -1 -o "$OUT" --start-number 1 HEAD
mv "$OUT"/0001-*.patch "$OUT/control-vla.patch"
git -C "$W" reset --quiet --hard "$BASE_SHA"

rc=0
echo
echo "### control 1: checkpatch error must be NEW"
"$REPO/scripts/ci-local.sh" --tree "$TREE" --base "$BASE" --checks am,checkpatch,gitlint --label control-checkpatch-error --out "$OUT/run-checkpatch-error" "$OUT/control-checkpatch-error.patch"
if grep -qE '^checkpatch +NEW' "$OUT/run-checkpatch-error/summary.txt" && grep -q '^ERROR:' "$OUT/run-checkpatch-error/checkpatch.txt"; then
	echo "control 1: OK — CheckPatch reported NEW with an ERROR: line"
else
	echo "control 1: FAILED — CheckPatch did not report NEW"; rc=1
fi

if (( ! SKIP_SMATCH )); then
	echo
	echo "### control 2: VLA must be NEW for smatch, with btdev.c:479 PRE-EXISTING"
	"$REPO/scripts/ci-local.sh" --tree "$TREE" --base "$BASE" --checks am,smatch --label control-vla --out "$OUT/run-vla" "$OUT/control-vla.patch"
	cls="$OUT/run-vla/smatch.classified.txt"
	if grep -qE '^smatch +NEW' "$OUT/run-vla/summary.txt" && grep -q '^NEW: emulator/btdev.c:.*Variable length array' "$cls" && grep -q '^PRE-EXISTING: emulator/btdev.c:479:.*Variable length array' "$cls"; then
		echo "control 2: OK — the injected VLA is NEW and btdev.c:479 is PRE-EXISTING"
	else
		echo "control 2: FAILED — see $cls"; rc=1
	fi
fi
echo
echo "controls written to $OUT"
exit $rc

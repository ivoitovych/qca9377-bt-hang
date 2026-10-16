#!/bin/bash
# functional-repeat.sh — run one (or a few) of BlueZ's functional tests
# (test/test-functional, the pytest-bluezenv VM harness the CI bot's
# TestFunctional runs) N times on a base tree and N times on base plus
# patches, and count the failures on each side: the failure RATE is what
# tells a flaky test from a regression. Written for the bot's
# test_bluetoothctl_pair_bredr failure of 2026-10-10.
#
#   scripts/functional-repeat.sh --kernel <bzImage> -k <pytest -k expr> [options] [<patch>...]
#
# Options
#   --tree DIR        BlueZ tree (default cache/bluez)
#   --base REF        base ref (default origin/master)
#   --runs N          runs per side (default 10)
#   --venv DIR        harness venv (default cache/bluezenv-venv; system python
#                     with --system-site-packages for dbus and gi)
#   --vm-timeout S    passed to test-functional (the bot uses 60)
#   --jobs N          make -j (default nproc)
#   --out DIR         (default tmp/functional-repeat/<UTC stamp>-<label>)
#   --label NAME
#   --keep-work
#
# Without patches only the base side runs. BlueZ is built as the bot's
# TestFunctional builds it: ./bootstrap-configure --disable-lsan --enable-asan
# --enable-ubsan. Without /dev/kvm the VMs run under TCG (qemu's own fallback
# in test-runner's accel=kvm:tcg), which is slow and changes timings; the
# summary says which it was. Output: <out>/<side>.<n>.xml and .out, and
# <out>/summary.txt with "side: K failures in N runs" and the failing test
# names with their first message line.
set -uo pipefail
export LC_ALL=C
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TREE="$REPO/cache/bluez"
BASE=origin/master
RUNS=10
VENV="$REPO/cache/bluezenv-venv"
VM_TIMEOUT=60
JOBS="$(nproc)"
OUT=""
LABEL=""
KERNEL=""
KEXPR=""
KEEP_WORK=0
PATCHES=()
while (( $# )); do
	case "$1" in
	--kernel) KERNEL="$(readlink -f "$2")"; shift ;;
	-k) KEXPR="$2"; shift ;;
	--tree) TREE="$2"; shift ;;
	--base) BASE="$2"; shift ;;
	--runs) RUNS="$2"; shift ;;
	--venv) VENV="$2"; shift ;;
	--vm-timeout) VM_TIMEOUT="$2"; shift ;;
	--jobs) JOBS="$2"; shift ;;
	--out) OUT="$2"; shift ;;
	--label) LABEL="$2"; shift ;;
	--keep-work) KEEP_WORK=1 ;;
	-h|--help) sed -n '2,32p' "$0"; exit 0 ;;
	-*) echo "functional-repeat: unknown option $1" >&2; exit 2 ;;
	*) PATCHES+=("$(readlink -f "$1")") ;;
	esac
	shift
done
[[ -f "$KERNEL" ]] || { echo "functional-repeat: --kernel <bzImage> is required" >&2; exit 2; }
[[ -n "$KEXPR" ]] || { echo "functional-repeat: -k <expression> is required" >&2; exit 2; }
[[ -x "$VENV/bin/python" ]] || { echo "functional-repeat: no venv at $VENV" >&2; exit 2; }
[[ -z "$LABEL" ]] && LABEL="$(echo "$KEXPR" | tr -c 'A-Za-z0-9_' '-' | cut -c1-40)"
[[ -z "$OUT" ]] && OUT="$REPO/tmp/functional-repeat/$(date -u +%Y%m%dT%H%M%SZ)-$LABEL"
mkdir -p "$OUT" || exit 2
OUT="$(readlink -f "$OUT")"
SUMMARY="$OUT/summary.txt"
BASE_SHA="$(git -C "$TREE" rev-parse --verify "$BASE^{commit}")" || exit 2
WORK="$OUT/work"; mkdir -p "$WORK"
SRC="$WORK/src"
git -C "$TREE" worktree add --quiet --detach "$SRC" "$BASE_SHA" || exit 2
ln -sfn "$REPO/cache/ell" "$WORK/ell"
cleanup() { (( KEEP_WORK )) || { git -C "$TREE" worktree remove --force "$SRC" 2>/dev/null; rm -rf "$WORK"; }; }
trap cleanup EXIT
log() { printf '%s %s\n' "$(date -u +%H:%M:%S)" "$*" | tee -a "$OUT/run.log"; }
{
	echo "base $BASE_SHA $(git -C "$TREE" log -1 --format='%cs %s' "$BASE_SHA")"
	echo "kernel $KERNEL"
	echo "selection -k '$KEXPR', $RUNS run(s) per side, --vm-timeout $VM_TIMEOUT"
	echo "harness: $("$VENV/bin/pip" show pytest-bluezenv 2>/dev/null | awk '/^Version/{print "pytest-bluezenv " $2}'), $("$VENV/bin/python" -c 'import pytest; print("pytest", pytest.__version__)')"
	echo "kvm: $([[ -c /dev/kvm ]] && echo yes || echo 'no (TCG)')"
	for p in "${PATCHES[@]}"; do echo "patch $(basename "$p")"; done
	echo
} | tee "$SUMMARY"

sides=(base)
(( ${#PATCHES[@]} )) && sides+=(patched)
for side in "${sides[@]}"; do
	git -C "$SRC" reset --quiet --hard "$BASE_SHA"
	if [[ "$side" == patched ]]; then
		git -C "$SRC" am --quiet "${PATCHES[@]}" >>"$OUT/run.log" 2>&1 || { echo "git am failed" | tee -a "$SUMMARY"; exit 2; }
	fi
	log "building BlueZ ($side): bootstrap-configure --disable-lsan --enable-asan --enable-ubsan"
	( cd "$SRC" && ./bootstrap-configure --disable-lsan --enable-asan --enable-ubsan ) >"$OUT/build.$side.configure.log" 2>&1 || { echo "configure failed ($side)" | tee -a "$SUMMARY"; exit 2; }
	( cd "$SRC" && make -j"$JOBS" ) >"$OUT/build.$side.make.log" 2>&1 || { echo "make failed ($side)" | tee -a "$SUMMARY"; exit 2; }
	fails=0
	for n in $(seq 1 "$RUNS"); do
		log "$side run $n/$RUNS"
		( cd "$SRC" && PATH="$VENV/bin:$PATH" timeout 3600 test/test-functional -vv --junit-xml "$OUT/$side.$n.xml" -m "not tester" -ra --vm-timeout "$VM_TIMEOUT" --kernel "$KERNEL" -k "$KEXPR" ) >"$OUT/$side.$n.out" 2>&1
		echo "exit status $?" >>"$OUT/$side.$n.out"
		python3 -I - "$OUT/$side.$n.xml" >"$OUT/$side.$n.result" <<'PY' || true
import sys, xml.etree.ElementTree as ET
try:
    tree = ET.parse(sys.argv[1])
except Exception as e:
    print(f"NO-RESULT {e}"); sys.exit(0)
n = 0
for tc in tree.findall(".//testcase"):
    n += 1
    name = tc.attrib.get("classname", "") + "::" + tc.attrib["name"]
    if tc.findall(".//skipped"):
        print(f"SKIP {name}: {tc.find('.//skipped').attrib.get('message','')[:160]}"); continue
    errs = tc.findall(".//error") + tc.findall(".//failure")
    if errs:
        msg = (errs[0].attrib.get("message") or errs[0].tag).splitlines()[0]
        print(f"FAIL {name}: {msg[:200]}")
    else:
        print(f"PASS {name}")
if n == 0:
    print("NO-RESULT no testcase in the junit file")
PY
		if grep -qE '^(FAIL|NO-RESULT)' "$OUT/$side.$n.result"; then fails=$((fails + 1)); fi
		printf '%-8s run %2d: %s\n' "$side" "$n" "$(tr '\n' ' ' <"$OUT/$side.$n.result" | cut -c1-200)" | tee -a "$SUMMARY"
	done
	echo "$side: $fails failure(s) in $RUNS run(s)" | tee -a "$SUMMARY"
	echo | tee -a "$SUMMARY"
done
exit 0

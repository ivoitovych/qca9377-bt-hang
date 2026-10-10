#!/bin/bash
# bluez-tester-compare.sh — run BlueZ's emulator-based testers (mgmt-tester,
# l2cap-tester, ...) in QEMU on a base tree and on base plus patches, the way
# the kernel CI bot's TestRunner does (tools/test-runner, ASan build, kernel
# built with doc/tester.config), and compare the verdict of every test case
# by name: a case that passes on the base and fails with the patches is a
# regression; the totals alone hide it.
#
#   scripts/bluez-tester-compare.sh --kernel <bzImage> [options] <patch>...
#
# Options
#   --tree DIR        BlueZ tree (default cache/bluez)
#   --base REF        base ref (default origin/master)
#   --testers LIST    comma-separated (default mgmt-tester,l2cap-tester,sco-tester,iso-tester,mesh-tester)
#   --runs N          runs per side per tester (default 1; more to see flakiness)
#   --jobs N          make -j (default nproc)
#   --out DIR         (default tmp/tester-compare/<UTC stamp>-<label>)
#   --label NAME
#   --keep-work
#
# Output: <out>/<tester>.<side>.<n>.log (test-runner output), <out>/summary.txt
# with, per tester: the Total line of each run, the cases whose verdict
# differs between the sides, and the sanitizer reports (the bot runs with
# ASAN_OPTIONS=exitcode=65:detect_leaks=0:print_summary=1, so leaks are not
# counted; this script prints LeakSanitizer output separately when present).
# Without /dev/kvm test-runner's "accel=kvm:tcg" falls back to software
# emulation: much slower, and timing-dependent cases may differ from the bot.
# Exit status 1 if any case passes on the base and fails with the patches.
set -uo pipefail
export LC_ALL=C
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TREE="$REPO/cache/bluez"
BASE=origin/master
TESTERS="mgmt-tester,l2cap-tester,sco-tester,iso-tester,mesh-tester"
RUNS=1
JOBS="$(nproc)"
OUT=""
LABEL=""
KERNEL=""
KEEP_WORK=0
PATCHES=()
while (( $# )); do
	case "$1" in
	--kernel) KERNEL="$(readlink -f "$2")"; shift ;;
	--tree) TREE="$2"; shift ;;
	--base) BASE="$2"; shift ;;
	--testers) TESTERS="$2"; shift ;;
	--runs) RUNS="$2"; shift ;;
	--jobs) JOBS="$2"; shift ;;
	--out) OUT="$2"; shift ;;
	--label) LABEL="$2"; shift ;;
	--keep-work) KEEP_WORK=1 ;;
	-h|--help) sed -n '2,30p' "$0"; exit 0 ;;
	-*) echo "bluez-tester-compare: unknown option $1" >&2; exit 2 ;;
	*) PATCHES+=("$(readlink -f "$1")") ;;
	esac
	shift
done
[[ -f "$KERNEL" ]] || { echo "bluez-tester-compare: --kernel <bzImage> is required" >&2; exit 2; }
(( ${#PATCHES[@]} )) || { echo "bluez-tester-compare: no patches given" >&2; exit 2; }
[[ -z "$LABEL" ]] && LABEL="$(basename "${PATCHES[0]}" .patch | cut -c1-40)"
[[ -z "$OUT" ]] && OUT="$REPO/tmp/tester-compare/$(date -u +%Y%m%dT%H%M%SZ)-$LABEL"
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
	for p in "${PATCHES[@]}"; do echo "patch $(basename "$p")"; done
	echo "kvm: $([[ -c /dev/kvm ]] && echo yes || echo 'no (TCG)')"
	echo
} | tee "$SUMMARY"

build_side() {   # build_side <side>
	git -C "$SRC" reset --quiet --hard "$BASE_SHA"
	if [[ "$1" == patched ]]; then
		git -C "$SRC" am --quiet "${PATCHES[@]}" >>"$OUT/run.log" 2>&1 || { echo "git am failed" | tee -a "$SUMMARY"; return 1; }
	fi
	log "building BlueZ ($1) with --disable-lsan, as the bot's TestRunnerSetup"
	( cd "$SRC" && ./bootstrap-configure --disable-lsan ) >"$OUT/build.$1.configure.log" 2>&1 || { echo "configure failed ($1)" | tee -a "$SUMMARY"; return 1; }
	( cd "$SRC" && make -j"$JOBS" ) >"$OUT/build.$1.make.log" 2>&1 || { echo "make failed ($1)" | tee -a "$SUMMARY"; return 1; }
	[[ -x "$SRC/tools/test-runner" ]] || { echo "no tools/test-runner ($1)" | tee -a "$SUMMARY"; return 1; }
}

# verdicts <log> -> "name<TAB>verdict" lines from the Test Summary block
verdicts() {
	python3 -I - "$1" <<'PY'
import re, sys
txt = open(sys.argv[1], errors="replace").read()
txt = re.sub(r"\x1b\[[0-9;]*m", "", txt)
m = re.search(r"^Test Summary\n-+\n(.*?)^Total:", txt, re.S | re.M)
if not m:
    sys.exit(0)
for line in m.group(1).splitlines():
    mm = re.match(r"^(.*?)\s+(Passed|Failed|Not Run|Timed out)\s+[\d.]+ seconds\s*$", line)
    if mm:
        print(f"{mm.group(1).strip()}\t{mm.group(2)}")
PY
}

rc=0
for side in base patched; do
	build_side "$side" || { rc=2; continue; }
	for t in ${TESTERS//,/ }; do
		[[ -x "$SRC/tools/$t" ]] || { echo "$t: not built" | tee -a "$SUMMARY"; continue; }
		for n in $(seq 1 "$RUNS"); do
			logf="$OUT/$t.$side.$n.log"
			log "run $t ($side, run $n)"
			( cd "$SRC" && timeout 7200 tools/test-runner -k "$KERNEL" -- /usr/bin/env ASAN_OPTIONS=exitcode=65:detect_leaks=0:print_summary=1 "tools/$t" ) >"$logf" 2>&1
			echo "exit status $?" >>"$logf"
			verdicts "$logf" >"$OUT/$t.$side.$n.verdicts"
			printf '%-14s %-8s run %d: %s\n' "$t" "$side" "$n" "$(grep -E '^Total:' "$logf" | tail -1 | sed 's/\x1b\[[0-9;]*m//g')" | tee -a "$SUMMARY"
		done
	done
done

echo | tee -a "$SUMMARY"
for t in ${TESTERS//,/ }; do
	[[ -f "$OUT/$t.base.1.verdicts" && -f "$OUT/$t.patched.1.verdicts" ]] || continue
	python3 -I - "$OUT" "$t" "$RUNS" <<'PY' | tee -a "$SUMMARY"
import sys, collections, os
out, t, runs = sys.argv[1], sys.argv[2], int(sys.argv[3])
def load(side):
    v = collections.defaultdict(list)
    for n in range(1, runs + 1):
        p = f"{out}/{t}.{side}.{n}.verdicts"
        if not os.path.exists(p): continue
        for line in open(p):
            name, verdict = line.rstrip("\n").split("\t")
            v[name].append(verdict)
    return v
b, p = load("base"), load("patched")
names = sorted(set(b) | set(p))
print(f"== {t}: {len(names)} case names; base runs {runs}, patched runs {runs}")
regress = 0
for n in names:
    vb, vp = b.get(n, []), p.get(n, [])
    if vb != vp:
        tag = ""
        if vb and vp and all(x == "Passed" for x in vb) and any(x != "Passed" for x in vp):
            tag = "  <-- passes on the base, not with the patches"; regress += 1
        if not vb: tag = "  (new case)"
        if not vp: tag = "  (case removed)"
        print(f"   {n}: base {vb} patched {vp}{tag}")
print(f"   cases with identical verdicts on both sides: {sum(1 for n in names if b.get(n, []) == p.get(n, []))}")
print(f"   REGRESSIONS: {regress}")
sys.exit(1 if regress else 0)
PY
	[[ ${PIPESTATUS[0]} -eq 0 ]] || rc=1
	for side in base patched; do
		for n in $(seq 1 "$RUNS"); do
			f="$OUT/$t.$side.$n.log"
			[[ -f "$f" ]] || continue
			if grep -q "LeakSanitizer\|ERROR: AddressSanitizer" "$f"; then
				echo "   sanitizer in $t.$side.$n.log:" | tee -a "$SUMMARY"
				grep -E "SUMMARY: (Leak|Address)Sanitizer|ERROR: AddressSanitizer|Direct leak of" "$f" | sed 's/^/      /' | tee -a "$SUMMARY"
			fi
		done
	done
done
echo | tee -a "$SUMMARY"
(( rc == 1 )) && echo "RESULT: regressions found" | tee -a "$SUMMARY"
(( rc == 0 )) && echo "RESULT: no case passes on the base and fails with the patches" | tee -a "$SUMMARY"
exit $rc

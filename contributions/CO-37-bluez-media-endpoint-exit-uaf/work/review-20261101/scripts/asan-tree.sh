#!/bin/bash
# asan-tree.sh build <name> <base ref> [<commit>...]
#     Clone ../repo at <base ref>, cherry-pick the commits in order, build
#     with the CI bot's TestFunctional flags (--disable-lsan --enable-asan
#     --enable-ubsan) in the bot's image.
# asan-tree.sh test <name> <label> <runs> <pytest args...>
#     Run "python3 -m pytest <pytest args...>" <runs> times in that tree
#     (two QEMU guests per test), one log per run:
#     runs/<name>/<label>-<i>.log (pytest -rA output) and
#     runs/<name>/<label>-<i>.debug.log (all guest output).
# asan-tree.sh check <name>
#     make check in that tree.
#
# Adapted from /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh (same
# image, kernel, ELL, flags). Containers get only --device /dev/kvm.
set -u
W=/root/exp/agent-work/co23-co37-review-20261101
IMG=bluez-action-ci:60348956fc7b
KSRC=/root/exp/agent-work/co23/bzImage-bot-base-47d4d9f67e92
KIMG=/kernel/bzImage
ELLSRC=/root/exp/agent-work/co23/ell-src
ELLREV=002b32d7c091
PROG=$W/progress.log

mode=$1 name=$2
d=$W/runs/$name

log() {
	echo "$(date '+%H:%M:%S') $*" | tee -a "$PROG"
}

run_docker() {
	docker run --rm --device=/dev/kvm:/dev/kvm \
		--volume "$W:$W" --volume "$KSRC:$KIMG:ro" \
		--workdir "$d/src" "$@"
}

case "$mode" in
build)
	base=$3
	shift 3
	[[ -e "$d" ]] && { echo "refusing: $d exists"; exit 2; }
	mkdir -p "$d"
	log "start build $name ($base $*)"
	git clone --quiet --no-checkout "$W/repo" "$d/src" || exit 2
	git -C "$d/src" checkout --quiet --detach "$base" || exit 2
	for c in "$@"; do
		git -C "$d/src" -c user.name=local -c user.email=local \
			cherry-pick "$c" > /dev/null ||
			{ echo "cherry-pick $c FAILED"; log "end build $name: cherry-pick $c FAILED"; exit 2; }
	done
	git clone --quiet --no-checkout "$ELLSRC" "$d/ell" || exit 2
	git -C "$d/ell" checkout --quiet --detach "$ELLREV" || exit 2
	git -C "$d/src" log --oneline "$base"~1..HEAD | tee "$d/commits.txt"
	echo "ell $(git -C "$d/ell" rev-parse HEAD)" | tee -a "$d/commits.txt"
	run_docker --entrypoint bash "$IMG" -c \
		"./bootstrap-configure --disable-lsan --enable-asan --enable-ubsan && make -j8" \
		> "$d/build.log" 2>&1
	rc=$?
	log "end build $name exit $rc"
	(( rc == 0 )) || { tail -30 "$d/build.log"; exit 1; }
	echo "warnings: $(grep -c "warning:" "$d/build.log")"
	exit 0
	;;
test)
	label=$3 n=$4
	shift 4
	[[ -d "$d/src" ]] || { echo "no tree $d/src"; exit 2; }
	log "start test $name $label x$n: $*"
	fails=0
	for i in $(seq 1 "$n"); do
		out=$d/$label-$i
		[[ -e "$out.log" ]] && { echo "refusing: $out.log exists"; exit 2; }
		t0=$(date '+%H:%M:%S')
		run_docker --entrypoint python3 "$IMG" -m pytest "$@" \
			-rA -p no:cacheprovider \
			--bluez-src-dir "$d/src" --bluez-build-dir "$d/src" \
			--kernel "$KIMG" --vm-timeout 60 \
			--log-file "$out.debug.log" --log-file-level 1 \
			> "$out.log" 2>&1
		rc=$?
		(( rc == 0 )) || fails=$((fails + 1))
		asan=$(grep -c "ERROR: AddressSanitizer" "$out.debug.log")
		summary=$(grep -E "^=+ .*(passed|failed|error).* =+$" "$out.log" | tail -1)
		echo "$label run $i ($t0 to $(date '+%H:%M:%S')) exit $rc asan-reports $asan: $summary" | tee -a "$d/$label.results"
	done
	echo "$label: $fails failures in $n runs" | tee -a "$d/$label.results"
	log "end test $name $label: $fails failures in $n runs"
	;;
testsrc)
	# testsrc <name> <test source checkout> <label> <runs> <pytest args...>
	# As test, but the tests (and client/scripts) come from a separate,
	# unbuilt checkout; the binaries from the built tree <name>.
	ts=$3 label=$4 n=$5
	shift 5
	[[ -d "$d/src" && -d "$ts/test/functional" ]] || { echo "no tree $d/src or $ts"; exit 2; }
	log "start testsrc $name ($ts) $label x$n: $*"
	fails=0
	for i in $(seq 1 "$n"); do
		out=$d/$label-$i
		[[ -e "$out.log" ]] && { echo "refusing: $out.log exists"; exit 2; }
		t0=$(date '+%H:%M:%S')
		docker run --rm --device=/dev/kvm:/dev/kvm \
			--volume "$W:$W" --volume "$KSRC:$KIMG:ro" \
			--workdir "$ts" --entrypoint python3 "$IMG" -m pytest "$@" \
			-rA -p no:cacheprovider \
			--bluez-src-dir "$ts" --bluez-build-dir "$d/src" \
			--kernel "$KIMG" --vm-timeout 60 \
			--log-file "$out.debug.log" --log-file-level 1 \
			> "$out.log" 2>&1
		rc=$?
		(( rc == 0 )) || fails=$((fails + 1))
		asan=$(grep -c "ERROR: AddressSanitizer" "$out.debug.log")
		summary=$(grep -E "^=+ .*(passed|failed|error).* =+$" "$out.log" | tail -1)
		echo "$label run $i ($t0 to $(date '+%H:%M:%S')) exit $rc asan-reports $asan: $summary" | tee -a "$d/$label.results"
	done
	echo "$label: $fails failures in $n runs (tests from $ts at $(git -C "$ts" rev-parse --short HEAD))" | tee -a "$d/$label.results"
	log "end testsrc $name $label: $fails failures in $n runs"
	;;
check)
	[[ -d "$d/src" ]] || { echo "no tree $d/src"; exit 2; }
	log "start make check $name"
	run_docker --entrypoint bash "$IMG" -c "make -j8 check" \
		> "$d/make-check.log" 2>&1
	rc=$?
	log "end make check $name exit $rc"
	grep -E "^# (TOTAL|PASS|SKIP|XFAIL|FAIL|XPASS|ERROR):" "$d/make-check.log"
	grep -E "^(FAIL|ERROR):" "$d/make-check.log"
	grep -c "AddressSanitizer\|runtime error:" "$d/make-check.log"
	exit $rc
	;;
*)
	echo "usage: $0 build|test|check ..."
	exit 2
	;;
esac

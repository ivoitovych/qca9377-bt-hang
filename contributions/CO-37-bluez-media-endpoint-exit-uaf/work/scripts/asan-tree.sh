#!/bin/bash
# asan-tree.sh build <name> <base ref> [<commit>...]
#     Clone /root/exp/agent-work/exit-uaf/repo at <base ref>, cherry-pick the
#     commits in order, and build it with the CI bot's TestFunctional flags
#     (--disable-lsan --enable-asan --enable-ubsan) in the bot's image.
#     A <name> starting with "revert-" reverts the commits instead.
# asan-tree.sh test <name> <pytest -k expression> <runs> <label>
#     Run test/functional -k <expression> <runs> times in that tree, two QEMU
#     guests per run, one log per run: runs/<name>/<label>-<i>.log (pytest -rA
#     output) and <label>-<i>.debug.log (all guest output).
# asan-tree.sh check <name>
#     make check in that tree.
# asan-tree.sh suite <name> <label>
#     The whole functional suite once, as the bot runs it (no -k).
#
# Containers get only --device /dev/kvm. The kernel is the tester kernel of
# CO-23 (bluetooth-next 47d4d9f67e92, doc/tester.config), mounted read-only.
set -u
W=/root/exp/agent-work/exit-uaf
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
		if [[ "$name" == revert-* ]]; then
			git -C "$d/src" -c user.name=local -c user.email=local \
				revert --no-edit "$c" > /dev/null ||
				{ echo "revert $c FAILED"; exit 2; }
		else
			git -C "$d/src" -c user.name=local -c user.email=local \
				cherry-pick "$c" > /dev/null ||
				{ echo "cherry-pick $c FAILED"; exit 2; }
		fi
	done
	git clone --quiet --no-checkout "$ELLSRC" "$d/ell" || exit 2
	git -C "$d/ell" checkout --quiet --detach "$ELLREV" || exit 2
	git -C "$d/src" log --oneline -4 | tee "$d/commits.txt"
	echo "ell $(git -C "$d/ell" rev-parse HEAD)" | tee -a "$d/commits.txt"
	run_docker --entrypoint bash "$IMG" -c \
		"./bootstrap-configure --disable-lsan --enable-asan --enable-ubsan && make -j12" \
		> "$d/build.log" 2>&1
	rc=$?
	log "end build $name exit $rc"
	(( rc == 0 )) || { tail -30 "$d/build.log"; exit 1; }
	echo "warnings: $(grep -c "warning:" "$d/build.log")"
	exit 0
	;;
remake)
	# Re-run make in a configured tree with extra arguments, e.g.
	# CFLAGS="-g -O2 -Wno-error" for 5.72 with a newer compiler
	# (the sanitizer flags are in MISC_CFLAGS, not CFLAGS)
	shift 2
	[[ -d "$d/src" ]] || { echo "no tree $d/src"; exit 2; }
	log "start remake $name ($*)"
	echo "remake: make $*" >> "$d/commits.txt"
	run_docker --entrypoint make "$IMG" -j12 "$@" > "$d/build-remake.log" 2>&1
	rc=$?
	log "end remake $name exit $rc"
	(( rc == 0 )) || { tail -30 "$d/build-remake.log"; exit 1; }
	echo "warnings: $(grep -c "warning:" "$d/build-remake.log")"
	exit 0
	;;
test)
	expr=$3 n=$4 label=$5
	[[ -d "$d/src" ]] || { echo "no tree $d/src"; exit 2; }
	log "start test $name $label -k '$expr' x$n"
	fails=0
	for i in $(seq 1 "$n"); do
		out=$d/$label-$i
		[[ -e "$out.log" ]] && { echo "refusing: $out.log exists"; exit 2; }
		run_docker --entrypoint python3 "$IMG" -m pytest test/functional \
			-rA -k "$expr" -p no:cacheprovider \
			--bluez-src-dir "$d/src" --bluez-build-dir "$d/src" \
			--kernel "$KIMG" --vm-timeout 60 \
			--log-file "$out.debug.log" --log-file-level 1 \
			> "$out.log" 2>&1
		rc=$?
		(( rc == 0 )) || fails=$((fails + 1))
		asan=$(grep -c "ERROR: AddressSanitizer" "$out.debug.log")
		summary=$(grep -E "^=+ .*(passed|failed|error).* =+$" "$out.log" | tail -1)
		echo "$label run $i exit $rc asan-reports $asan: $summary" | tee -a "$d/$label.results"
	done
	echo "$label: $fails failures in $n runs" | tee -a "$d/$label.results"
	log "end test $name $label: $fails failures in $n runs"
	;;
check)
	[[ -d "$d/src" ]] || { echo "no tree $d/src"; exit 2; }
	log "start make check $name"
	run_docker --entrypoint bash "$IMG" -c "make -j12 check" \
		> "$d/make-check.log" 2>&1
	rc=$?
	log "end make check $name exit $rc"
	grep -E "^# (TOTAL|PASS|SKIP|XFAIL|FAIL|XPASS|ERROR):" "$d/make-check.log"
	grep -E "^(FAIL|ERROR):" "$d/make-check.log"
	grep -c "AddressSanitizer\|runtime error:" "$d/make-check.log"
	exit $rc
	;;
suite)
	label=$3
	[[ -d "$d/src" ]] || { echo "no tree $d/src"; exit 2; }
	out=$d/$label
	[[ -e "$out.log" ]] && { echo "refusing: $out.log exists"; exit 2; }
	log "start suite $name $label"
	run_docker --entrypoint python3 "$IMG" -m pytest test/functional \
		-rA -p no:cacheprovider \
		--bluez-src-dir "$d/src" --bluez-build-dir "$d/src" \
		--kernel "$KIMG" --vm-timeout 60 \
		--junit-xml "$out.xml" \
		--log-file "$out.debug.log" --log-file-level 1 \
		> "$out.log" 2>&1
	rc=$?
	log "end suite $name $label exit $rc"
	grep -E "^(PASSED|FAILED|ERROR|SKIPPED|XFAIL|XPASS) " "$out.log" | sort > "$out.verdicts"
	grep -E "^=+ .*(passed|failed|error).* =+$" "$out.log" | tail -1
	exit $rc
	;;
*)
	echo "usage: $0 build|test|check|suite ..."
	exit 2
	;;
esac

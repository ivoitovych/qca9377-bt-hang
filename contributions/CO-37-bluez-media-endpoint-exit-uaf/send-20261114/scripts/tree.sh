#!/bin/bash
# Adapted from the CO-37 release campaign's tree.sh (/root/exp/agent-work/co37-release-20261102/scripts/tree.sh).
# tree.sh build <name> <repo> <ref>
#     Clone <repo> at <ref> into runs/<name>/src, ELL beside it, and build in the CI bot's image with
#     bootstrap-configure --disable-lsan --enable-asan --enable-ubsan && make -j4.
# tree.sh run <tree> <out> <label> <runs> <test source checkout> <pytest args...>
#     "python3 -m pytest <args>" <runs> times with the binaries of runs/<tree>/src and the tests of the
#     test source checkout. Per run: runs/<out>/<label>-<i>.log, .debug.log; a line per run in <label>.results.
# tree.sh check <tree>      make check in runs/<tree>/src
# tree.sh suite <tree> <out> <label> <test source checkout>   the whole functional suite once
# Stops (exit 3) when less than 15 GB are free.
set -u
ulimit -c 0
W=/root/exp/agent-work/lane4-bluez-20261114/co37
IMG=bluez-action-ci:c7d077f185cd
KSRC=/root/exp/agent-work/lane4-bluez-20261114/project/tmp/kernel/bzImage-base
KIMG=/kernel/bzImage
ELLSRC=/root/exp/agent-work/lane4-bluez-20261114/cache/ell
ELLREV=$(git -C "$ELLSRC" rev-parse origin/master)
PROG=$W/progress.log
MIN_FREE_MB=15360

log() { echo "$(date '+%H:%M:%S') $*" | tee -a "$PROG"; }

check_df() {
	local avail
	avail=$(df -B1M --output=avail /root | tail -1 | tr -d ' ')
	if (( avail < MIN_FREE_MB )); then
		log "STOP: only ${avail} MB free (minimum ${MIN_FREE_MB})"
		exit 3
	fi
}

mode=$1
case "$mode" in
build)
	name=$2 repo=$3 ref=$4
	d=$W/runs/$name
	[[ -e "$d" ]] && { echo "refusing: $d exists"; exit 2; }
	check_df
	mkdir -p "$d"
	t0=$(date '+%H:%M:%S')
	log "start build $name ($repo $ref)"
	git clone --quiet --no-checkout "$repo" "$d/src" || exit 2
	git -C "$d/src" checkout --quiet --detach "$ref" || exit 2
	git clone --quiet --no-checkout "$ELLSRC" "$d/ell" || exit 2
	git -C "$d/ell" checkout --quiet --detach "$ELLREV" || exit 2
	echo "HEAD $(git -C "$d/src" rev-parse HEAD) (from $repo $ref)" | tee "$d/commits.txt"
	echo "ell $ELLREV" | tee -a "$d/commits.txt"
	docker run --rm --ulimit core=0 --volume "$W:$W" --workdir "$d/src" --entrypoint bash "$IMG" -c \
		"./bootstrap-configure --disable-lsan --enable-asan --enable-ubsan && make -j4" \
		> "$d/build.log" 2>&1
	rc=$?
	log "end build $name exit $rc ($t0 to $(date '+%H:%M:%S'))"
	(( rc == 0 )) || { tail -30 "$d/build.log"; exit 1; }
	echo "warnings: $(grep -c "warning:" "$d/build.log")" | tee -a "$d/commits.txt"
	exit 0
	;;
run)
	tree=$2 out=$3 label=$4 n=$5 ts=$6
	shift 6
	b=$W/runs/$tree/src
	o=$W/runs/$out
	[[ -x "$b/src/bluetoothd" ]] || { echo "no bluetoothd in $b"; exit 2; }
	[[ -d "$ts/test/functional" ]] || { echo "no tests in $ts"; exit 2; }
	mkdir -p "$o"
	mounts=(--volume "$W:$W" --volume "$KSRC:$KIMG:ro")
	check_df
	tb=$(date '+%H:%M:%S')
	log "start run $out $label x$n (binaries $tree, tests $ts at $(git -C "$ts" rev-parse --short HEAD)): $*"
	fails=0
	for i in $(seq 1 "$n"); do
		check_df
		f=$o/$label-$i
		[[ -e "$f.log" ]] && { echo "refusing: $f.log exists"; exit 2; }
		t0=$(date '+%H:%M:%S')
		docker run --rm --ulimit core=0 --device=/dev/kvm:/dev/kvm \
			"${mounts[@]}" --workdir "$o" --entrypoint python3 "$IMG" \
			-m pytest "$@" -rA -p no:cacheprovider \
			--bluez-src-dir "$ts" --bluez-build-dir "$b" \
			--kernel "$KIMG" --vm-timeout 60 \
			--log-file "$f.debug.log" --log-file-level 1 \
			> "$f.log" 2>&1
		rc=$?
		(( rc == 0 )) || fails=$((fails + 1))
		asan=$(grep -c "ERROR: AddressSanitizer" "$f.debug.log")
		ubsan=$(grep -c "runtime error:" "$f.debug.log")
		first=$(grep -m1 -A1 "ERROR: AddressSanitizer" "$f.debug.log" | tr '\n' ' ' | cut -c1-200)
		where=$(grep -m1 -E "^.*#0 0x[0-9a-f]+ in " "$f.debug.log" | sed 's/.*#0 0x[0-9a-f]* in //' | cut -c1-120)
		summary=$(grep -E "^=+ .*(passed|failed|error|skipped).* =+$" "$f.log" | tail -1)
		find "$o" -maxdepth 1 -name '*.core' -type f -delete
		echo "$label run $i ($t0 to $(date '+%H:%M:%S')) exit $rc asan-reports $asan ubsan $ubsan top-frame [$where]: $summary" | tee -a "$o/$label.results"
	done
	echo "$label: $fails failing pytest runs of $n (binaries $tree, tests $ts)" | tee -a "$o/$label.results"
	log "end run $out $label: $fails failing pytest runs of $n ($tb to $(date '+%H:%M:%S'))"
	;;
check)
	tree=$2
	d=$W/runs/$tree
	[[ -e "$d/make-check.log" ]] && { echo "refusing: $d/make-check.log exists"; exit 2; }
	check_df
	log "start make check $tree"
	docker run --rm --ulimit core=0 --volume "$W:$W" --workdir "$d/src" \
		--entrypoint bash "$IMG" -c "make -j4 check" > "$d/make-check.log" 2>&1
	rc=$?
	log "end make check $tree exit $rc"
	grep -E "^# (TOTAL|PASS|SKIP|XFAIL|FAIL|XPASS|ERROR):" "$d/make-check.log"
	grep -E "^(FAIL|ERROR):" "$d/make-check.log"
	exit $rc
	;;
suite)
	tree=$2 out=$3 label=$4 ts=$5
	b=$W/runs/$tree/src
	o=$W/runs/$out
	mkdir -p "$o"
	f=$o/$label
	[[ -e "$f.log" ]] && { echo "refusing: $f.log exists"; exit 2; }
	mounts=(--volume "$W:$W" --volume "$KSRC:$KIMG:ro")
	check_df
	log "start suite $tree $out $label"
	docker run --rm --ulimit core=0 --device=/dev/kvm:/dev/kvm \
		"${mounts[@]}" --workdir "$o" --entrypoint python3 "$IMG" \
		-m pytest "$ts/test/functional" -rA -p no:cacheprovider \
		--bluez-src-dir "$ts" --bluez-build-dir "$b" \
		--kernel "$KIMG" --vm-timeout 60 \
		--junit-xml "$f.xml" \
		--log-file "$f.debug.log" --log-file-level 1 \
		> "$f.log" 2>&1
	rc=$?
	log "end suite $tree $out $label exit $rc"
	grep -E "^(PASSED|FAILED|ERROR|SKIPPED|XFAIL|XPASS) " "$f.log" | sort > "$f.verdicts"
	grep -E "^=+ .*(passed|failed|error).* =+$" "$f.log" | tail -1
	echo "asan-reports $(grep -c "ERROR: AddressSanitizer" "$f.debug.log")"
	exit 0
	;;
*)
	echo "usage: $0 build|run|check|suite ..."
	exit 2
	;;
esac

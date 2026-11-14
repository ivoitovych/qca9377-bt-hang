#!/bin/bash
# asan-tree.sh build <name> <base ref> [<commit>...] | test <name> <label> <runs> <pytest args...> | check <name>
# Adapted from /root/exp/agent-work/co23-co37-review-20261101/scripts/asan-tree.sh (same bot image, kernel,
# ELL revision, flags: --disable-lsan --enable-asan --enable-ubsan; two QEMU guests per test).
# Work area: lane2-sco-20261114/co23/asan/<name>/ ; repo: ../bluez (clone). Container gets only /dev/kvm.
set -u
W=/root/exp/agent-work/lane2-sco-20261114/co23/asan
REPO=/root/exp/agent-work/lane2-sco-20261114/bluez
IMG=bluez-action-ci:60348956fc7b
KSRC=/root/exp/agent-work/co23/bzImage-bot-base-47d4d9f67e92
KIMG=/kernel/bzImage
ELLSRC=/root/exp/agent-work/lane2-sco-20261114/project/cache/ell
ELLREV=002b32d7c091
mkdir -p "$W"
mode=$1 name=$2
d=$W/$name
avail_kb=$(df -Pk /root | awk 'NR==2 {print $4}')
if (( avail_kb < 25 * 1024 * 1024 )); then echo "STOP: under 25 GB free"; exit 3; fi

run_docker() {
	docker run --rm --device=/dev/kvm:/dev/kvm --volume "$W:$W" --volume "$KSRC:$KIMG:ro" --workdir "$d/src" "$@"
}

case "$mode" in
build)
	base=$3
	shift 3
	[[ -e "$d" ]] && { echo "refusing: $d exists"; exit 2; }
	mkdir -p "$d"
	git clone --quiet --no-checkout "$REPO" "$d/src" || exit 2
	git -C "$d/src" checkout --quiet --detach "$base" || exit 2
	for c in "$@"; do
		git -C "$d/src" -c user.name=local -c user.email=local cherry-pick "$c" > /dev/null || { echo "cherry-pick $c FAILED"; exit 2; }
	done
	git clone --quiet --no-checkout "$ELLSRC" "$d/ell" || exit 2
	git -C "$d/ell" checkout --quiet --detach "$ELLREV" || exit 2
	git -C "$d/src" log --oneline "$base"..HEAD > "$d/commits.txt"
	echo "ell $(git -C "$d/ell" rev-parse HEAD)" >> "$d/commits.txt"
	run_docker --entrypoint bash "$IMG" -c "./bootstrap-configure --disable-lsan --enable-asan --enable-ubsan && make -j4" > "$d/build.log" 2>&1
	rc=$?
	echo "build $name exit $rc, warnings: $(grep -c 'warning:' "$d/build.log")"
	exit $rc
	;;
test)
	label=$3 n=$4
	shift 4
	[[ -d "$d/src" ]] || { echo "no tree $d/src"; exit 2; }
	fails=0
	for i in $(seq 1 "$n"); do
		out=$d/$label-$i
		[[ -e "$out.log" ]] && { echo "exists, skipped: $out.log"; continue; }
		t0=$(date '+%H:%M:%S')
		run_docker --entrypoint python3 "$IMG" -m pytest "$@" -rA -p no:cacheprovider \
			--bluez-src-dir "$d/src" --bluez-build-dir "$d/src" --kernel "$KIMG" --vm-timeout 60 \
			--log-file "$out.debug.log" --log-file-level 1 > "$out.log" 2>&1
		rc=$?
		(( rc == 0 )) || fails=$((fails + 1))
		asan=$(grep -c "ERROR: AddressSanitizer" "$out.debug.log")
		summary=$(grep -E "^=+ .*(passed|failed|error).* =+$" "$out.log" | tail -1)
		echo "$label run $i ($t0 to $(date '+%H:%M:%S')) exit $rc asan-reports $asan: $summary" | tee -a "$d/$label.results"
	done
	echo "$label: $fails failures in $n runs" | tee -a "$d/$label.results"
	;;
check)
	[[ -d "$d/src" ]] || { echo "no tree $d/src"; exit 2; }
	run_docker --entrypoint bash "$IMG" -c "make -j4 check" > "$d/make-check.log" 2>&1
	rc=$?
	grep -E "^# (TOTAL|PASS|SKIP|XFAIL|FAIL|XPASS|ERROR):" "$d/make-check.log"
	echo "sanitizer lines: $(grep -c 'AddressSanitizer\|runtime error:' "$d/make-check.log")"
	exit $rc
	;;
*)
	echo "usage: $0 build|test|check ..."
	exit 2
	;;
esac

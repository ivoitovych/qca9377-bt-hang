#!/bin/bash
# asan-ext.sh <built tree dir> <out dir> <test source checkout> <label> <runs> <pytest args...>
# As asan-tree.sh testsrc, for a tree built elsewhere (mounted read-only),
# e.g. /root/exp/agent-work/exit-uaf/runs/v572/src (5.72 with master's
# test tools). Outputs go to <out dir> under this work area.
set -u
W=/root/exp/agent-work/co23-co37-review-20261101
IMG=bluez-action-ci:60348956fc7b
KSRC=/root/exp/agent-work/co23/bzImage-bot-base-47d4d9f67e92
KIMG=/kernel/bzImage
PROG=$W/progress.log
b=$1 o=$2 ts=$3 label=$4 n=$5
shift 5
[[ "$o" == "$W"/* ]] || { echo "refusing: $o is outside $W"; exit 2; }
mkdir -p "$o"
log() { echo "$(date '+%H:%M:%S') $*" | tee -a "$PROG"; }
log "start ext $b -> $o ($ts) $label x$n: $*"
fails=0
for i in $(seq 1 "$n"); do
	out=$o/$label-$i
	[[ -e "$out.log" ]] && { echo "refusing: $out.log exists"; exit 2; }
	t0=$(date '+%H:%M:%S')
	docker run --rm --device=/dev/kvm:/dev/kvm \
		--volume "$W:$W" --volume "$b:$b:ro" --volume "$KSRC:$KIMG:ro" \
		--workdir "$ts" --entrypoint python3 "$IMG" -m pytest "$@" \
		-rA -p no:cacheprovider \
		--bluez-src-dir "$ts" --bluez-build-dir "$b" \
		--kernel "$KIMG" --vm-timeout 60 \
		--log-file "$out.debug.log" --log-file-level 1 \
		> "$out.log" 2>&1
	rc=$?
	(( rc == 0 )) || fails=$((fails + 1))
	asan=$(grep -c "ERROR: AddressSanitizer" "$out.debug.log")
	summary=$(grep -E "^=+ .*(passed|failed|error).* =+$" "$out.log" | tail -1)
	echo "$label run $i ($t0 to $(date '+%H:%M:%S')) exit $rc asan-reports $asan: $summary" | tee -a "$o/$label.results"
done
echo "$label: $fails failures in $n runs (binaries $b, tests $ts at $(git -C "$ts" rev-parse --short HEAD))" | tee -a "$o/$label.results"
log "end ext $o $label: $fails failures in $n runs"

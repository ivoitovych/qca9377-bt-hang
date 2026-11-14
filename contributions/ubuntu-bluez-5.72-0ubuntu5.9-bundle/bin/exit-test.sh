#!/bin/bash
# exit-test.sh <name> <pytest -k expression> <runs> <label>
# CO-37's runner (asan-tree.sh test): test/functional -k <expr>, <runs> times in exit/<name>/src, two QEMU guests per run,
# one log per run; the bot image with only /dev/kvm; the tester kernel of CO-23, read-only.
set -u
B=/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle
W=$B/exit
IMG=bluez-action-ci:60348956fc7b
KSRC=/root/exp/agent-work/co23/bzImage-bot-base-47d4d9f67e92
KIMG=/kernel/bzImage
name=$1 expr=$2 n=$3 label=$4
d=$W/$name
[[ -d $d/src ]] || { echo "no tree $d/src"; exit 2; }
echo "$(date -u '+%F %T') UTC exit-test: $name $label -k '$expr' x$n" >> "$B/logs/progress.log"
fails=0
for i in $(seq 1 "$n"); do
	out=$d/$label-$i
	[[ -e "$out.log" ]] && { echo "refusing: $out.log exists"; exit 2; }
	docker run --rm --device=/dev/kvm:/dev/kvm --volume "$W:$W" --volume "$KSRC:$KIMG:ro" --workdir "$d/src" \
		--entrypoint python3 "$IMG" -m pytest test/functional -rA -k "$expr" -p no:cacheprovider \
		--bluez-src-dir "$d/src" --bluez-build-dir "$d/src" --kernel "$KIMG" --vm-timeout 60 \
		--log-file "$out.debug.log" --log-file-level 1 > "$out.log" 2>&1
	rc=$?
	(( rc == 0 )) || fails=$((fails + 1))
	asan=$(grep -c "ERROR: AddressSanitizer" "$out.debug.log")
	summary=$(grep -E "^=+ .*(passed|failed|error).* =+$" "$out.log" | tail -1)
	echo "$label run $i exit $rc asan-reports $asan: $summary" | tee -a "$d/$label.results"
done
echo "$label: $fails failures in $n runs" | tee -a "$d/$label.results"
echo "$(date -u '+%F %T') UTC exit-test end: $name $label: $fails failures in $n runs" >> "$B/logs/progress.log"

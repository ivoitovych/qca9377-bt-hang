#!/bin/bash
# run-batch-usbip.sh <spec file> <summary file>
# As run-batch.sh, through run-guest-usbip.sh (the CO-21 / CO-20 usbip emulator).
set -u
w=/root/exp/agent-work/lane1-btusb-20261114/task3
spec=${1:?usage}
out=${2:?usage}
: >"$out"
runs=0
failed=0
while read -r tag label rest; do
	case "$tag" in
	'' | '#'*) continue ;;
	esac
	runs=$((runs + 1))
	# shellcheck disable=SC2086
	"$w/harness/run-guest-usbip.sh" "$tag" "$label" $rest >/dev/null </dev/null
	rc=$?
	verdict=PASS
	if [ $rc -ne 0 ]; then
		verdict=FAIL
		failed=$((failed + 1))
	fi
	echo "$tag $label exit=$rc $verdict $(grep -a -h -o 'RESULT .*' "$w/logs/runs/$tag-$label.log" | tail -n 1)" >>"$out"
done <"$spec"
echo "batch: $runs runs, $failed FAIL" >>"$out"
[ "$failed" -eq 0 ]

#!/bin/bash
# run-batch.sh <spec file> <summary file>
# Spec file: one run per line, "<kernel tag> <label> <scenario and emulator args...>"; '#' lines
# and empty lines are skipped. Runs them one after the other through run-guest.sh (one guest
# at a time). Summary line per run: "<tag> <label> exit=<n> <PASS|FAIL> <last RESULT line>".
# The last line is "batch: <runs> runs, <failed> FAIL" and the exit status is 1 if any run
# failed, so a failed case fails the batch (task 1 fix 3). Cases whose failure is the expected
# finding (a kernel known to lack a fix) are read from the summary, not hidden: they still
# count as FAIL here.
set -u
w=/root/exp/agent-work/lane1-btusb-20261114/task1
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
	"$w/harness/run-guest.sh" "$tag" "$label" $rest >/dev/null </dev/null
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

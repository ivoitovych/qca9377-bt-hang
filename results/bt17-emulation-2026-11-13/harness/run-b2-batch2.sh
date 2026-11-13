#!/bin/bash
# run-b2-batch2.sh: sysfs reset runs (b2, ab2d, and base for comparison), the sysfs reset with a command
# deferred, and extra recover runs to see how often ab2d's recover run fails to power on.
# Summary: logs/matrix-b2-batch2.txt
set -u
w=/root/exp/agent-work/bt17-emu-20261113
out=$w/logs/matrix-b2-batch2.txt
: >"$out"
run() {
	tag=$1
	label=$2
	shift 2
	"$w/harness/run-guest.sh" "$tag" "$label" "$@" >/dev/null
	rc=$?
	echo "$tag $label exit=$rc $(grep -a -h -o 'RESULT .*' "$w/logs/$tag-$label.log" | tail -n 1)" >>"$out"
}
run ab2d h2-sysfs-1 sysfs-reset
run base h2-sysfs-1 sysfs-reset
run b2 h2-sysfs-def-1 sysfs-reset --while-deferred --fail-at 1
run ab2d h2-sysfs-def-1 sysfs-reset --while-deferred --fail-at 1
run base h2-sysfs-def-1 sysfs-reset --while-deferred --fail-at 1
for n in 4 5 6 7; do
	run abd "h2-recover-$n" bt17 --fail-at 1 --recover
	run final "h2-recover-$n" bt17 --fail-at 1 --recover
	run base "h2-recover-$n" bt17 --fail-at 1 --recover
done
for n in 4 5 6; do
	run ab2d "h2-recover-$n" bt17 --fail-at 1 --recover
done
echo done >>"$out"

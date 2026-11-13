#!/bin/bash
# run-b2-batch.sh: the B2 acceptance runs on kernels b2 and ab2d, one guest each, via run-guest.sh.
# Summary (label, exit status, RESULT line): logs/matrix-b2-batch.txt
set -u
w=/root/exp/agent-work/bt17-emu-20261113
out=$w/logs/matrix-b2-batch.txt
: >"$out"
run() {
	tag=$1
	label=$2
	shift 2
	"$w/harness/run-guest.sh" "$tag" "$label" "$@" >/dev/null
	rc=$?
	echo "$tag $label exit=$rc $(grep -a -h -o 'RESULT .*' "$w/logs/$tag-$label.log" | tail -n 1)" >>"$out"
}
for tag in b2 ab2d; do
	for n in 1 2 3; do
		run $tag "h2-bt17-$n" bt17 --fail-at 1
		run $tag "h2-dropcmd-$n" dropcmd
		run $tag "h2-wedge-$n" dropcmd-wedge --drop-hci-event 0x0c24 --wedge-until-reset
		run $tag "h2-recover-$n" bt17 --fail-at 1 --recover
		run $tag "h2-close-$n" close-recover --fail-at 1 --recover
	done
	run $tag h2-cycles50-1 cycles --cycles 50
done
echo done >>"$out"

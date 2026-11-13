#!/bin/bash
# run-wedge-batch.sh: the dropcmd-wedge runs (base 2-3 here; base 1 was run by hand), via run-guest.sh.
# Summary of exit codes: logs/matrix-wedge-batch.txt
set -u
w=/root/exp/agent-work/bt17-emu-20261113
out=$w/logs/matrix-wedge-batch.txt
: >"$out"
run() {
	"$w/harness/run-guest.sh" "$@" >/dev/null
	echo "$1 $2 exit=$?" >>"$out"
}
for n in 2 3; do run base "h-wedge-$n" dropcmd-wedge --drop-hci-event 0x0c24 --wedge-until-reset; done
for n in 1 2 3; do run ab "h-wedge-$n" dropcmd-wedge --drop-hci-event 0x0c24 --wedge-until-reset; done
for n in 1 2 3; do run final "h-wedge-$n" dropcmd-wedge --drop-hci-event 0x0c24 --wedge-until-reset; done
echo done >>"$out"

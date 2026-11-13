#!/bin/bash
# run-dropcmd-batch.sh: the 2026-11-13 counterexample runs, sequentially, via run-guest.sh.
# Summary of exit codes: logs/matrix-dropcmd-batch.txt
set -u
w=/root/exp/agent-work/bt17-emu-20261113
out=$w/logs/matrix-dropcmd-batch.txt
: >"$out"
run() {
	"$w/harness/run-guest.sh" "$@" >/dev/null
	echo "$1 $2 exit=$?" >>"$out"
}
for n in 2 3; do run base "h-dropcmd-$n" dropcmd; done
for n in 1 2 3; do run ab "h-dropcmd-$n" dropcmd; done
for n in 1 2 3; do run final "h-dropcmd-$n" dropcmd; done
run final h-recover-1 bt17 --fail-at 1 --recover
cat "$out"

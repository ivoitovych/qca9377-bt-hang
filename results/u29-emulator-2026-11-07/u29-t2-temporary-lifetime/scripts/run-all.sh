#!/bin/sh
# Every arm, repetitions 0..2, the arms in parallel (one container each at a
# time), the repetitions of an arm one after the other. An existing runs/<arm>-<n>
# directory is skipped (never overwritten).
# Usage: run-all.sh
top=/root/exp/agent-work/u29-t2-temporary-lifetime
chain() {
    arm=$1
    for n in 0 1 2; do
        if [ -e "$top/runs/$arm-$n" ]; then
            echo "skip $arm-$n (exists)"
            continue
        fi
        "$top/scripts/run-arm.sh" "$arm" "$n" || echo "FAILED $arm-$n"
    done
}
for arm in A B C D E F; do
    chain "$arm" &
done
wait
echo "all chains done"

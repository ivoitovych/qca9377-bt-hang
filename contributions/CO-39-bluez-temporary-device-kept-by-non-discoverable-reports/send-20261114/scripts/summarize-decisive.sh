#!/bin/bash
# One line per run of the decisive test: build, run number, pytest's final line, and the failing assertion.
top=/root/exp/agent-work/lane4-bluez-20261114/co39
out=$top/logs/decisive-summary.txt
{
    echo "decisive test: test/functional/test_device.py::test_device_temporary_not_discoverable, 7 runs per build"
    for b in master-base master-patched; do
        for n in 0 1 2 3 4 5 6; do
            f=$top/runs/$b-$n/stdout.log
            last=$(grep -a -E "^=+ .*(passed|failed).* in [0-9.]+s" "$f" | tail -1)
            where=$(grep -a -m1 -E "^[^ ]*test_device.py:[0-9]+: *$" "$f")
            echo "$b run $n: ${last:-NO RESULT LINE} ${where:+| failed at ${where##*/}}"
        done
    done
} > "$out"
cat "$out"

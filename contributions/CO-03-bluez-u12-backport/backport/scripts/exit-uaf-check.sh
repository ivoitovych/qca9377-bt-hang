#!/bin/sh
# Follow-up to the ASan report "heap-use-after-free profiles/audio/media.c:300
# in clear_endpoint" seen at bluetoothd exit in runs/v2-l3rates (2 of 10):
# the same L3 test with A2DP left connected at teardown (T311, stock remote),
# ten times on each build, to compare how often bluetoothd's exit path
# reports it. Runs base then backport.
set -u
s=/root/exp/agent-work/co03/scripts
r=/root/exp/agent-work/co03/runs
for v in base backport; do
    echo "== $v $(date -Is)"
    CO03_REPS=10 $s/run-l3.sh "$v" "exitcheck-$v-t311x10" -k "test_co03_pw and t311" \
        > "$r/exitcheck-$v-t311x10.stdout.log" 2>&1
    tail -1 "$r/exitcheck-$v-t311x10.stdout.log"
    grep -c "SUMMARY: AddressSanitizer" "$r/exitcheck-$v-t311x10/pytest.log"
    grep "SUMMARY: AddressSanitizer" "$r/exitcheck-$v-t311x10/pytest.log" | cut -c60-200
done
echo "== done $(date -Is)"

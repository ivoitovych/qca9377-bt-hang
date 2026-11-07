#!/bin/sh
# PipeWire's own VM tests (test/bluezenv/test_streaming.py), one pytest
# session (fresh guests) per test: with BlueZ 5.72 the reused guests keep
# the previous test's link key and the next pairing fails (AlreadyExists),
# and PipeWire's conftest is not ours to change.
# Usage: run-l3-pw-own.sh <variant> <run prefix>
set -u
variant=$1
prefix=$2
for t in test_pipewire_a2dp test_pipewire_profile_switch test_pipewire_hfp \
         test_pipewire_bluez_restart test_pipewire_bap_ucast \
         test_pipewire_bap_bcast test_pipewire_bap_profile_switch; do
    echo "== $t $(date -Is)"
    /root/exp/agent-work/co03/scripts/run-l3.sh "$variant" "$prefix-$t" -k "test_streaming and $t" \
        > "/root/exp/agent-work/co03/runs/$prefix-$t.stdout.log" 2>&1
    echo "exit $?: $(tail -1 "/root/exp/agent-work/co03/runs/$prefix-$t.stdout.log")"
done

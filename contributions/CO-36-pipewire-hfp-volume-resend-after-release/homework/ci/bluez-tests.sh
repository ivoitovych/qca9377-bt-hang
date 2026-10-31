#!/bin/sh
# Runs PipeWire's Bluetooth VM tests on a source tree, the way CI's
# bluez_tests job does, in the local image co36-pw-ci:f44.
# The container gets /dev/kvm and nothing else from the host's devices:
# no USB, not privileged, so the laptop's controller cannot be reached.
# Usage: bluez-tests.sh <pipewire source dir> <build dir name> [pytest args...]
# Output goes to stdout; redirect it to a log in tmp/co36/.
# Extra tests: every test_*.py in ../tests is mounted over test/bluezenv/
# of the source tree, so they run next to PipeWire's own.
set -eu

src=$1
shift

tests=/root/exp/qca9377-bt-hang/contributions/CO-36-pipewire-hfp-volume-resend-after-release/homework/tests
t=test_co36_hfp_volume_resend.py

exec docker run --rm \
    --device /dev/kvm \
    -v "$src:/src" \
    -v "$tests/$t:/src/test/bluezenv/$t:ro" \
    -v /root/exp/qca9377-bt-hang/contributions/CO-36-pipewire-hfp-volume-resend-after-release/homework/ci:/ci:ro \
    -w /src \
    co36-pw-ci:f44 \
    /bin/sh /ci/bluez-tests-inside.sh "$@"

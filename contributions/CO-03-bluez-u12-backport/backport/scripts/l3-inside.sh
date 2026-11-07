#!/bin/sh
# Runs inside co36-pw-ci:f44 (PipeWire's CI image): PipeWire's VM tests
# from /src (CO-03's copy of the CO-36 tree, build dir build-v0-asan), with
# the guests' BlueZ tools from /co03/build-f44/$CO03_VARIANT.
# Usage: l3-inside.sh [pytest args...]
set -eu
BUILD_DIR=/src/build-v0-asan
XDG_RUNTIME_DIR=$(mktemp -d /tmp/xdg-runtime-XXXXXX)
export XDG_RUNTIME_DIR
FUNCTIONAL_TESTING_CONTROLLERS=none
export FUNCTIONAL_TESTING_CONTROLLERS
UBSAN_OPTIONS=abort_on_error=1:print_summary=1:print_stacktrace=1
ASAN_OPTIONS=abort_on_error=1:print_summary=1:detect_leaks=1:leak_check_at_exit=0
export UBSAN_OPTIONS ASAN_OPTIONS
cd /src
exec meson devenv -C "$BUILD_DIR" -w . python3 -m pytest test \
    --kernel /bluez/bzImage* --bluez-src-dir "/co03/build-f44/$CO03_VARIANT" \
    -ra -vv --vm-timeout 30 -p no:cacheprovider \
    -o log_file="$CO03_RUNDIR/pytest.log" "$@"

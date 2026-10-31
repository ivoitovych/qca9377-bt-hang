#!/bin/sh
# Runs inside co36-pw-ci:f44: the script of PipeWire CI's bluez_tests job
# (.gitlab-ci.yml of 4cfc471123a0, lines 492-521), with the build directory
# named by $1 and extra pytest arguments after it.
# Usage: bluez-tests-inside.sh <build dir name> [pytest args...]
set -eu

name=$1
shift

BUILD_DIR="/src/$name"
PREFIX="/src/$name-prefix"
XDG_RUNTIME_DIR=$(mktemp -d /tmp/xdg-runtime-XXXXXX)
export XDG_RUNTIME_DIR

# Real controllers are never used: the container has no /dev/bus/usb, and
# no name here is a USB controller.
FUNCTIONAL_TESTING_CONTROLLERS=none
export FUNCTIONAL_TESTING_CONTROLLERS

if [ ! -f "$BUILD_DIR/build.ninja" ]; then
    meson setup "$BUILD_DIR" --prefix="$PREFIX" \
        -Ddocs=disabled \
        -Dman=disabled \
        -Dexamples=disabled \
        -Dtests=disabled \
        -Dgstreamer=disabled \
        -Davahi=disabled \
        -Dbluez5-backend-hsphfpd=enabled \
        -Dsession-managers=wireplumber \
        -Dsnap=disabled \
        -Droc=disabled \
        -Dlibcamera=disabled \
        -Db_sanitize=address,undefined \
        -Ddebug=true \
        -Doptimization=g
fi
meson compile -C "$BUILD_DIR"

# Where test_co36_*.py append what they saw, one JSON line per test
CO36_BUILD=$name
CO36_RESULTS="/src/$name-co36-results.jsonl"
export CO36_BUILD CO36_RESULTS

UBSAN_OPTIONS=abort_on_error=1:print_summary=1:print_stacktrace=1
ASAN_OPTIONS=abort_on_error=1:print_summary=1:detect_leaks=1:leak_check_at_exit=0
export UBSAN_OPTIONS ASAN_OPTIONS

cd /src
exec meson devenv -C "$BUILD_DIR" -w . python3 -m pytest test \
    --kernel /bluez/bzImage* --bluez-src-dir /bluez \
    -ra -vvv --reruns 1 --vm-timeout 30 "$@"

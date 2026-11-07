#!/bin/sh
# Runs inside co36-pw-ci:f44: the script of PipeWire CI's bluez_tests job
# (.gitlab-ci.yml of 4cfc471123a0, lines 492-521), as the homework's
# ci/bluez-tests-inside.sh, with three changes for this work area:
#  - results go to /out/<run id>-results.jsonl (CO36_RESULTS), not the tree;
#  - every log record of every test goes to /out/<run id>-pytest-log.txt
#    (pytest --log-file, level 1: the VMs' process output is logged at
#    pytest_bluezenv's level OUT = 5, below DEBUG; run r01 used DEBUG and
#    its log file lacks those lines), so sanitizer reports of passing
#    tests are kept too (T236);
#  - the run id and repeat count come from the caller (CO36_RUN, CO36_REPEAT).
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

CO36_BUILD=$name
CO36_RESULTS="/out/$CO36_RUN-results.jsonl"
export CO36_BUILD CO36_RESULTS CO36_RUN CO36_REPEAT

UBSAN_OPTIONS=abort_on_error=1:print_summary=1:print_stacktrace=1
ASAN_OPTIONS=abort_on_error=1:print_summary=1:detect_leaks=1:leak_check_at_exit=0
export UBSAN_OPTIONS ASAN_OPTIONS

cd /src
exec meson devenv -C "$BUILD_DIR" -w . python3 -m pytest test \
    --kernel /bluez/bzImage* --bluez-src-dir /bluez \
    -ra -vvv --reruns 1 --vm-timeout 30 \
    -p no:cacheprovider \
    --log-file "/out/$CO36_RUN-pytest-log.txt" --log-file-level 1 \
    --log-file-format "%(asctime)s.%(msecs)03d %(levelname)s %(name)s %(message)s" \
    --log-file-date-format "%H:%M:%S" \
    "$@"

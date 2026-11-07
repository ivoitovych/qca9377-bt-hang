#!/bin/sh
# T005, inside co36-pw-ci:f44: PipeWire CI's build_on_fedora job
# (.gitlab-ci.yml of 4cfc4711, lines 254-278 and 402-422): meson setup
# with its MESON_OPTIONS, compile, meson test --no-rebuild.
# No MESON_TEST_OPTIONS are set for build_on_fedora (line 384 is another job).
set -eu

BUILD_DIR=/src/build-t005
PREFIX=/src/build-t005-prefix
XDG_RUNTIME_DIR=$(mktemp -d /tmp/xdg-runtime-XXXXXX)
export XDG_RUNTIME_DIR

if [ ! -f "$BUILD_DIR/build.ninja" ]; then
    meson setup "$BUILD_DIR" --prefix="$PREFIX" \
        -Ddocs=enabled \
        -Dman=enabled \
        -Ddoc-prefix-value=/usr \
        -Ddoc-sysconfdir-value=/etc \
        -Dinstalled_tests=enabled \
        -Dsystemd-system-service=enabled \
        -Dbluez5-backend-hsphfpd=enabled \
        -Daudiotestsrc=enabled \
        -Dtest=enabled \
        -Dvideotestsrc=enabled \
        -Dvolume=enabled \
        -Dvulkan=enabled \
        -Dsdl2=enabled \
        -Dsndfile=enabled \
        -Dsession-managers=[] \
        -Dsnap=disabled
fi
echo "T005 compile start $(date +%H:%M:%S)"
meson compile -C "$BUILD_DIR" -j8
echo "T005 test start $(date +%H:%M:%S)"
set +e
meson test -C "$BUILD_DIR" --no-rebuild
rc=$?
echo "T005 meson test exit $rc at $(date +%H:%M:%S)"
cp "$BUILD_DIR/meson-logs/testlog.txt" /out/t005-testlog.txt
cp "$BUILD_DIR/meson-logs/testlog.json" /out/t005-testlog.json
exit $rc

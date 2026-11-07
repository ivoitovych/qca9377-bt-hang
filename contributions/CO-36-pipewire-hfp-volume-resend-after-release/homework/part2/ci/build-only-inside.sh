#!/bin/sh
# Inside co36-pw-ci:f44: meson setup + compile with CI's bluez_tests
# options (as bluez-tests-inside.sh), no tests.  For T308's tree with
# WirePlumber 0.4.17 as the subproject.
# Usage: build-only-inside.sh <build dir name> [extra meson setup args...]
set -eu
BUILD_DIR="/src/$1"
PREFIX="/src/$1-prefix"
shift
if [ ! -f "$BUILD_DIR/build.ninja" ]; then
    meson setup "$BUILD_DIR" --prefix="$PREFIX" "$@" \
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
meson compile -C "$BUILD_DIR" -j8
echo "build-only done"

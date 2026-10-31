#!/bin/sh
# Build both packaging trees with dpkg-buildpackage -b -us -uc in
# co03-noble-build:1, then run BlueZ's own unit tests (make check) in each
# configured tree. Logs: logs/pkg-build-<v>.log, logs/pkg-check-<v>.log,
# logs/pkg-check-<v>-test-suite.log.
# Usage: build-pkgs.sh [variant...]   (default: base backport)
set -u
top=/root/exp/agent-work/co03
ver=5.72-0ubuntu5.8
vs=${*:-base backport}
for v in $vs; do
    echo "== $v build $(date -Is)"
    docker run --rm -v "$top/pkg/$v:/build" -w "/build/bluez-$ver" \
        co03-noble-build:1 sh -c \
        'DEB_BUILD_OPTIONS=parallel=8 dpkg-buildpackage -b -us -uc; echo "dpkg-buildpackage exit $?"' \
        > "$top/logs/pkg-build-$v.log" 2>&1
    tail -1 "$top/logs/pkg-build-$v.log"
    echo "== $v check $(date -Is)"
    docker run --rm -v "$top/pkg/$v:/build" -w "/build/bluez-$ver" \
        co03-noble-build:1 sh -c 'make -j8 check; echo "make check exit $?"' \
        > "$top/logs/pkg-check-$v.log" 2>&1
    tail -1 "$top/logs/pkg-check-$v.log"
    cp "$top/pkg/$v/bluez-$ver/test-suite.log" "$top/logs/pkg-check-$v-test-suite.log" || true
done
echo "== done $(date -Is)"

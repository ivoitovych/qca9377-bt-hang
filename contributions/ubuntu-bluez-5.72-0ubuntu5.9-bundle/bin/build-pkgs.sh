#!/bin/bash
# build-pkgs.sh [base|bundle ...] : dpkg-buildpackage -b in the noble build container (parallel=4), then make check in the
# configured tree (the package disables dh_auto_test), then for the bundle also the source package (-S) and a debdiff
B=/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle
vs=${*:-base bundle}
for v in $vs; do
  case $v in base) d=$B/tree-base ;; bundle) d=$B/tree ;; *) exit 2 ;; esac
  echo "== $v build $(date -u '+%F %T') UTC" | tee -a "$B/logs/progress.log"
  docker run --rm -v "$d:/build" -w /build/bluez-5.72 co03-noble-build:1 sh -c \
    'DEB_BUILD_OPTIONS=parallel=4 dpkg-buildpackage -b -us -uc; echo "dpkg-buildpackage exit $?"' \
    > "$B/logs/pkg-build-$v.log" 2>&1
  tail -n 1 "$B/logs/pkg-build-$v.log" | tee -a "$B/logs/progress.log"
  echo "== $v make check $(date -u '+%F %T') UTC" | tee -a "$B/logs/progress.log"
  docker run --rm -v "$d:/build" -w /build/bluez-5.72 co03-noble-build:1 sh -c 'make -j4 check; echo "make check exit $?"' \
    > "$B/logs/pkg-check-$v.log" 2>&1
  tail -n 1 "$B/logs/pkg-check-$v.log" | tee -a "$B/logs/progress.log"
  cp "$d/bluez-5.72/test-suite.log" "$B/logs/pkg-check-$v-test-suite.log"
done
echo "PKGS-DONE $(date -u '+%F %T') UTC" | tee -a "$B/logs/progress.log"

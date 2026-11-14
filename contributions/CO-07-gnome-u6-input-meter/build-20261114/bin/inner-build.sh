#!/bin/sh
# Runs inside co03-noble-build:1 (Ubuntu 24.04). /w = the package's work dir with the three source files.
# usage: inner-build.sh <dsc> <new version> <patch files dir> <changelog entry file> <series lines file> <source dir name e.g. wireplumber-0.4.17>
set -u
DSC=$1; NEWV=$2; PD=$3; CL=$4; SER=$5
export DEBIAN_FRONTEND=noninteractive
cd /w || exit 2
rm -rf stock new srcnew
echo "== os"; grep -e ^VERSION= /etc/os-release
apt-get update -qq > apt-update.log 2>&1 || { echo "apt update failed"; exit 1; }
dpkg-source -x --no-check "$DSC" stock > extract-stock.log 2>&1 || { echo "extract failed"; exit 1; }
apt-get build-dep -y -qq ./stock > build-dep.log 2>&1 || { echo "build-dep failed"; tail -n 8 build-dep.log; exit 1; }
echo "build-dep ok"
echo "== new tree: unpack without patches, add ours"
dpkg-source -x --no-check --skip-patches "$DSC" new > extract-new.log 2>&1 || { echo "extract new failed"; exit 1; }
cd new || exit 2
for p in "$PD"/*.patch; do
  echo "-- dry run $(basename "$p")"; patch -p1 --dry-run < "$p" || echo "NOTE: does not apply on the unpatched tree (expected for a patch that builds on Ubuntu's)"
done
cd /w
# apply the Ubuntu series on a scratch copy to dry-run ours on top of it (fuzz 0)
cp -a stock scratch-check
( cd scratch-check && for p in "$PD"/*.patch; do patch -p1 --dry-run --fuzz=0 < "$p" && echo "applies on top of the full 5.x series: $(basename "$p")"; done )
rm -rf scratch-check
cd new
for p in "$PD"/*.patch; do cp "$p" debian/patches/; done
cat "$SER" >> debian/patches/series
cat "$CL" debian/changelog > ../changelog.tmp && cp ../changelog.tmp debian/changelog
dpkg-parsechangelog -S Version
cd /w
echo "== source package and debdiff"
mkdir -p srcnew; cp ./*.orig.tar.* srcnew/ 2>/dev/null
( cd srcnew && dpkg-source -b /w/new > ../dpkg-source-b.log 2>&1; echo "dpkg-source -b rc=$?" )
debdiff "$DSC" "srcnew/$(basename "$DSC" | sed "s/_.*//")_$NEWV.dsc" > debdiff.out 2> debdiff.err; echo "debdiff rc=$? (1 = differences)"
echo "== builds (stock first, then new), tests run by the package's own dh_auto_test"
export DEB_BUILD_OPTIONS="parallel=4"
( cd stock && dpkg-buildpackage -b -uc -us > ../build-stock.log 2>&1; echo $? > ../build-stock.rc )
( cd new && dpkg-buildpackage -b -uc -us > ../build-new.log 2>&1; echo $? > ../build-new.rc )
echo "stock rc $(cat build-stock.rc)  new rc $(cat build-new.rc)"
echo "== test lines"
for v in stock new; do echo "-- $v"; grep -a -E "^(Ok|Expected Fail|Fail|Unexpected Pass|Skipped|Timeout):|^ *[0-9]+/[0-9]+ .*(OK|FAIL|SKIP|TIMEOUT)|dh_auto_test|meson test|Testsuite summary|^# (TOTAL|PASS|FAIL)" build-$v.log | tail -n 25; done
echo "== done"

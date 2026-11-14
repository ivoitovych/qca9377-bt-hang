#!/bin/bash
# source package of the bundle, built from a fresh unpack (the build tree has generated files) and the debdiff against 5.8
B=/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle
S=$B/srcbuild
rm -rf "$S"; mkdir -p "$S" "$B/deliver"
docker run --rm -v "$B:/w" -w /w/srcbuild co03-noble-build:1 dpkg-source -x --no-check ../src/bluez_5.72-0ubuntu5.8.dsc > "$B/logs/srcbuild-unpack.log" 2>&1
T=$S/bluez-5.72
cp "$B"/patches/*.patch "$T/debian/patches/"
cat "$B/patches/series.fragment" >> "$T/debian/patches/series"
cat "$B/changelog-entry.txt" "$T/debian/changelog" > "$S/changelog.new" && cp "$S/changelog.new" "$T/debian/changelog"
cp "$B/src/bluez_5.72.orig.tar.xz" "$S/"
docker run --rm -v "$B:/w" -w /w/srcbuild/bluez-5.72 co03-noble-build:1 sh -c '
dpkg-buildpackage -S -us -uc -d 2>&1 | tail -n 12
cd /w/srcbuild
ls -la bluez_5.72-0ubuntu5.9.dsc bluez_5.72-0ubuntu5.9.debian.tar.xz
debdiff /w/src/bluez_5.72-0ubuntu5.8.dsc /w/srcbuild/bluez_5.72-0ubuntu5.9.dsc > /w/deliver/bluez_5.72-0ubuntu5.8_5.72-0ubuntu5.9.debdiff
echo "debdiff exit $?"
' > "$B/logs/src-pkg.log" 2>&1
tail -n 10 "$B/logs/src-pkg.log"

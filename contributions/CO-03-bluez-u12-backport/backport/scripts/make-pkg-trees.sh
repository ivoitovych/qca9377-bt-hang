#!/bin/sh
# Create the packaging trees from the archive's source package:
#   pkg/base/bluez-5.72-0ubuntu5.8      unchanged
#   pkg/backport/bluez-5.72-0ubuntu5.8  + debian/patches/co03-*.patch,
#                                       series entries, changelog entry,
#                                       patches applied with quilt
# Runs dpkg-source/dch/quilt inside co03-noble-build:1.
# Usage: make-pkg-trees.sh [base] [backport]   (default: both)
set -eu
top=/root/exp/agent-work/co03
ver=5.72-0ubuntu5.8
newver=5.72-0ubuntu5.9~co03.1
vs=${*:-base backport}
for v in $vs; do
    if [ -e "$top/pkg/$v" ]; then
        echo "exists: $top/pkg/$v" >&2
        exit 1
    fi
    mkdir -p "$top/pkg/$v"
done
for v in $vs; do
docker run --rm \
    -v "$top/src/archive:/archive:ro" \
    -v "$top/debian-patches:/patches:ro" \
    -v "$top/pkg:/pkg" \
    -e V="$v" \
    co03-noble-build:1 sh -c "
set -e
cd /pkg/\$V
dpkg-source -x /archive/bluez_$ver.dsc bluez-$ver
[ \"\$V\" = backport ] || exit 0
cd bluez-$ver
cp /patches/co03-*.patch debian/patches/
printf '\n# CO-03: crash fixes (BT-7) and the A2DP Release()-during-Acquire() fix\n' >> debian/patches/series
ls /patches/ | grep '^co03-.*\.patch\$' | sort >> debian/patches/series
export DEBFULLNAME='Iaroslav Voitovych' DEBEMAIL='yaroslav.voytovych@gmail.com'
dch -v $newver -D UNRELEASED \
  'd/p/co03-03, co03-04, co03-05: backport upstream fix: Release() during a pending A2DP Acquire() no longer aborts the stream and disconnects A2DP (upstream commits 3d9900eb754d (helper part), a14d59725ef3, 664a5d3785a1)'
dch -a 'd/p/co03-01: adapter: Fix crash on short start discovery reply (upstream commit a734b06059cb)'
dch -a 'd/p/co03-02: a2dp: Fix crash on NULL stream in transport_cb (upstream commit 0bed9886cff3)'
QUILT_PATCHES=debian/patches quilt push -a
head -20 debian/changelog
tail -8 debian/patches/series
"
done

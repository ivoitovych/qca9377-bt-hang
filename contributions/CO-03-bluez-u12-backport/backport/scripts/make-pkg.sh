#!/bin/sh
# Packaging trees of the three-patch candidate, from the archive's source
# package bluez_5.72-0ubuntu5.8.dsc, in co03-noble-build:1:
#   pkg/ppa/bluez-5.72   version 5.72-0ubuntu5.9~ppa1 (the binary test build)
#   pkg/sru/bluez-5.72   version 5.72-0ubuntu5.9      (the debdiff for review)
# Each: the patches of debian-patches/ copied to debian/patches/, appended
# to the series in order, a changelog entry, quilt push -a (fuzz refused),
# then dpkg-source -b (source package). Then: debdiff archive -> sru, and
# the patched source compared with the git worktree build/cand3.
# Usage: make-pkg.sh
set -eu
R=/root/exp/agent-work/co03/review-20261101
A=/root/exp/agent-work/co03/src/archive
for v in ppa sru; do
    [ -e "$R/pkg/$v" ] && { echo "exists: $R/pkg/$v" >&2; exit 1; }
    mkdir -p "$R/pkg/$v"
done
"$R/scripts/log.sh" "START make-pkg (ppa, sru trees)"
for v in ppa sru; do
    if [ "$v" = ppa ]; then ver=5.72-0ubuntu5.9~ppa1; else ver=5.72-0ubuntu5.9; fi
    docker run --rm \
        -v "$A:/archive:ro" \
        -v "$R/debian-patches:/patches:ro" \
        -v "$R/pkg/$v:/pkg" \
        -e VER="$ver" \
        co03-noble-build:1 sh -c '
set -e
cd /pkg
dpkg-source -x /archive/bluez_5.72-0ubuntu5.8.dsc bluez-5.72
cd bluez-5.72
for p in $(cat /patches/series); do cp /patches/$p debian/patches/; echo $p >> debian/patches/series; done
{ printf "bluez (%s) UNRELEASED; urgency=medium\n\n" "$VER"
  cat /patches/changelog-entry.txt
  printf "\n -- Iaroslav Voitovych <yaroslav.voytovych@gmail.com>  %s\n\n" "$(date -R)"
  cat debian/changelog; } > /tmp/changelog.new
mv /tmp/changelog.new debian/changelog
dpkg-parsechangelog -S Version
awk "length > 80 { print \"LONG LINE \" NR \": \" length }" debian/changelog | head -3
QUILT_PATCHES=debian/patches quilt push -a --fuzz=0
echo "== changelog head"; head -12 debian/changelog
echo "== series tail"; tail -5 debian/patches/series
cd /pkg
dpkg-source -b bluez-5.72
ls -la /pkg
'
done
echo "== debdiff 5.72-0ubuntu5.8 -> 5.72-0ubuntu5.9"
docker run --rm -v "$A:/archive:ro" -v "$R/pkg:/pkg" co03-noble-build:1 sh -c \
    'debdiff /archive/bluez_5.72-0ubuntu5.8.dsc /pkg/sru/bluez_5.72-0ubuntu5.9.dsc > /pkg/bluez_5.72-0ubuntu5.8_5.72-0ubuntu5.9.debdiff; echo "debdiff exit $? (1 = differences found)"; dpkg --compare-versions 5.72-0ubuntu5.9~ppa1 gt 5.72-0ubuntu5.8 && echo "ppa1 > 5.8: yes"; dpkg --compare-versions 5.72-0ubuntu5.9~ppa1 lt 5.72-0ubuntu5.9 && echo "ppa1 < 5.9: yes"' || true
echo "== patched package source vs git branch rev/cand3 (git archive export)"
rm -rf "$R/tmp/cand3-export"
mkdir -p "$R/tmp/cand3-export"
git -C "$R/src/bluez" archive rev/cand3 | tar -x -C "$R/tmp/cand3-export"
if diff -r -q -x debian -x .pc "$R/pkg/ppa/bluez-5.72" "$R/tmp/cand3-export"; then
    echo "IDENTICAL (outside debian/ and .pc/)"
else
    echo "DIFFERENT (list above)"
fi
"$R/scripts/log.sh" "END make-pkg"

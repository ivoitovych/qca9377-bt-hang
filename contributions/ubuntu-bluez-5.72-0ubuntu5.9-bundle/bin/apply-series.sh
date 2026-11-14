#!/bin/bash
# base tree -> tree-base (pristine 5.72-0ubuntu5.8, patches applied by dpkg-source) ; bundle tree -> tree (patches added)
B=/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle
L=$B/logs/apply-series.log
mkdir -p "$B/tree-base"
if [[ ! -d $B/tree-base/bluez-5.72 ]]; then
  docker run --rm -v "$B:/w" -w /w/tree-base co03-noble-build:1 dpkg-source -x --no-check ../src/bluez_5.72-0ubuntu5.8.dsc > "$B/logs/unpack-base.log" 2>&1
fi
T=$B/tree/bluez-5.72
cp "$B"/patches/*.patch "$T/debian/patches/"
cat "$B/patches/series.fragment" >> "$T/debian/patches/series"
cat "$B/changelog-entry.txt" "$T/debian/changelog" > "$B/logs/changelog.new" && cp "$B/logs/changelog.new" "$T/debian/changelog"
docker run --rm -v "$B:/w" -w /w/tree/bluez-5.72 co03-noble-build:1 sh -c '
export QUILT_PATCHES=debian/patches QUILT_PC=.pc
echo "== quilt pop -a"; quilt pop -a 2>&1 | tail -n 3
echo "== quilt push -a --fuzz=0"; quilt push -a --fuzz=0 2>&1
echo "== quilt applied"; quilt applied | wc -l
echo "== dpkg-parsechangelog"; dpkg-parsechangelog -S Version
' > "$L" 2>&1
echo APPLY-DONE >> "$L"

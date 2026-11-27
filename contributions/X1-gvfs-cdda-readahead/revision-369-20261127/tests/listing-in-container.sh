#!/bin/bash
# listing-in-container.sh — INSIDE ubuntu:26.04: run only the listing test (gvfs-cdda-listing-test.py)
#   /cases  base/ patch1/ revised/ and the test programs;  /out  output directory
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
apt-get update -qq
apt-get install -y -qq gcc python3 pkg-config dpkg-dev libglib2.0-dev libcdio-dev libcdio-paranoia-dev > /out/listing-deps.log 2>&1
mkdir /w
cd /w
apt-get source -qq libcdio > /dev/null 2>&1
LIB=$(find /w -maxdepth 1 -type d -name "libcdio-*" | head -1)
echo "gcc $(gcc -dumpfullversion), glib $(pkg-config --modversion glib-2.0), libcdio $(pkg-config --modversion libcdio), libcdio_paranoia $(pkg-config --modversion libcdio_paranoia), source $LIB" > /out/listing-run.log
printf "test\tcase\tsource\texit\tlast line\n" > /out/listing-results.tsv
while read -r label args; do
  [ -z "$label" ] && continue
  for s in base patch1 revised; do
    res=$(timeout 60 python3 -I /cases/gvfs-cdda-listing-test.py "/cases/$s/daemon/gvfsbackendcdda.c" "$LIB" $args 2>&1)
    rc=$?
    echo "=== listing $label $s exit $rc" >> /out/listing-run.log
    echo "$res" >> /out/listing-run.log
    printf "listing\t%s\t%s\t%s\t%s\n" "$label" "$s" "$rc" "$(echo "$res" | tail -1)" >> /out/listing-results.tsv
  done
done <<CASES
tracks-1-3 1
tracks-2-4 2
tracks-5-7 5
tracks-1-3_data-3 1 --data 3
tracks-2-4_data-2 2 --data 2
CASES
echo done >> /out/listing-run.log

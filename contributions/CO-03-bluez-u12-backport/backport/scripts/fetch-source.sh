#!/bin/sh
# Fetch Ubuntu noble's bluez source package (newest noble version) into
# /root/exp/agent-work/co03/src/archive, inside the co03-noble-build:1 image.
# Usage: fetch-source.sh <version>
set -eu
ver=${1:-5.72-0ubuntu5.8}
out=/root/exp/agent-work/co03/src/archive
mkdir -p "$out"
exec docker run --rm -v "$out:/out" -w /out co03-noble-build:1 sh -c "
set -e
apt-get update -qq
apt-get source --download-only bluez=$ver
dpkg-source -x bluez_$ver.dsc bluez-$ver
ls -la /out
"

#!/bin/sh
# Download the archive's own bluez 5.72-0ubuntu5.8 (the version the laptop has) into the kit,
# so a rollback needs no network.  Runs in a throw-away ubuntu:24.04 container.
top=/root/exp/agent-work/laptop-headset-session-20261111
out=$top/kit/artifacts/bluez-5.72-0ubuntu5.8-archive
mkdir -p "$out"
"$top/scripts/log.sh" START download-rollback-debs
docker run --rm -v "$out:/out" ubuntu:24.04 sh -c '
set -e
apt-get update -qq
cd /out
apt-get download bluez=5.72-0ubuntu5.8
ls -l /out
'
echo "exit $?"
"$top/scripts/log.sh" END download-rollback-debs

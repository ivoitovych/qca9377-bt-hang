#!/bin/bash
# is the btmon work of CO-11a already in tenacious's bluez 5.88-1 (source package from Launchpad)?
T=/root/exp/agent-work/lane5-status-stable-20261114/task4
W=$T/work
mkdir -p "$W/build/tenacious"
docker run --rm -v "$W:/w" ubuntu:26.10 sh -c '
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null 2>&1; apt-get install -y -qq dpkg-dev xz-utils patch >/dev/null 2>&1
rm -rf /w/build/tenacious/src
dpkg-source -x --no-check /w/src/tenacious/bluez_5.88-1.dsc /w/build/tenacious/src > /w/build/tenacious/extract.log 2>&1; echo "extract rc=$?"
cd /w/build/tenacious/src
echo "== changelog head"; head -n 4 debian/changelog
echo "== fdbfe0018f6f: if (max_len <= 0) recovery in print_packet"
grep -n -B1 -A3 "max_len <= 0" monitor/packet.c
echo "== dca0f10fd560: clamp (sizeof(line) - pos - 1)"
grep -n -B1 -A4 "sizeof(line) - pos - 1" monitor/packet.c
echo "== 6475b75e7e0e (CVE-2026-105460): Return Link Keys length check"
grep -n -B3 -A6 "too short packet" monitor/packet.c | grep -n -A8 -B4 "num_keys \* 22"
echo "== debian patches touching monitor/"
grep -l "monitor/" debian/patches/*.patch
echo "== series"; cat debian/patches/series
' > "$T/logs/tenacious-check.log" 2>&1
cat "$T/logs/tenacious-check.log"

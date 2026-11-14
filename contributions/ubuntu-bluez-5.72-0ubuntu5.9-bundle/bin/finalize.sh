#!/bin/bash
# collect the deliverables, remove the big build trees and my docker images, write SHA256SUMS
B=/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle
mkdir -p "$B/deliver/debs"
cp "$B/srcbuild/bluez_5.72-0ubuntu5.9.dsc" "$B/srcbuild/bluez_5.72-0ubuntu5.9.debian.tar.xz" "$B/deliver/"
cp -a "$B/srcbuild/bluez-5.72/debian" "$B/deliver/debian-5.72-0ubuntu5.9"
cp "$B/tree/bluez_5.72-0ubuntu5.9_amd64.deb" "$B/tree/libbluetooth3_5.72-0ubuntu5.9_amd64.deb" "$B/tree/bluetooth_5.72-0ubuntu5.9_all.deb" "$B/tree/bluez_5.72-0ubuntu5.9_amd64.buildinfo" "$B/tree/bluez_5.72-0ubuntu5.9_amd64.changes" "$B/deliver/debs/"
cp "$B/btmon-replay/inputs.sha256" "$B/logs/btmon-replay-inputs.sha256"
du -sh "$B"/* > "$B/logs/sizes-before-cleanup.txt"
rm -rf "$B/tree" "$B/tree-base" "$B/fresh" "$B/srcbuild" "$B/asan" "$B/exit/master" "$B/exit/e572base/src" "$B/exit/e572bundle/src" "$B/exit/e572base/ell" "$B/exit/e572bundle/ell" "$B/installed"
docker rmi bundle572-installed:bundle bundle572-installed:stock > /dev/null 2>&1
du -sh "$B" >> "$B/logs/sizes-before-cleanup.txt"
cd "$B" && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
wc -l SHA256SUMS
du -sh "$B"

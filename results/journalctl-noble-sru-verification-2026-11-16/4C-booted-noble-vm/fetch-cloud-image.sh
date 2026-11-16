#!/bin/bash
# 4C: the official Ubuntu 24.04 (noble) server cloud image, verified against the SHA256SUMS of the same directory.
D=<work dir>/verify/vm
mkdir -p $D
cd $D
base=https://cloud-images.ubuntu.com/noble/current
curl -sSL --max-time 120 -o SHA256SUMS $base/SHA256SUMS
curl -sSL --max-time 120 -o SHA256SUMS.gpg $base/SHA256SUMS.gpg
grep 'noble-server-cloudimg-amd64.img' SHA256SUMS
if [ ! -s noble-server-cloudimg-amd64.img ]; then
    curl -sSL --max-time 1800 -o noble-server-cloudimg-amd64.img $base/noble-server-cloudimg-amd64.img
fi
ls -l noble-server-cloudimg-amd64.img
sha256sum noble-server-cloudimg-amd64.img
echo "--- check against SHA256SUMS:"
grep ' \*\?noble-server-cloudimg-amd64.img$' SHA256SUMS | sha256sum -c -
curl -sSL --max-time 60 -I $base/noble-server-cloudimg-amd64.img | grep -i "last-modified\|content-length"

#!/bin/bash
# 4C: data ISO (stock and test debs, writer scripts), working copy of the cloud image.
V=<work dir>/verify/vm
cd $V
mkdir -p data/stock819 data/test
cp ../../pkgx/dl819/*.deb data/stock819/
for p in systemd systemd-sysv systemd-dev libsystemd0 libsystemd-shared libudev1 udev libpam-systemd libnss-systemd systemd-resolved systemd-timesyncd systemd-journal-remote; do
    cp ../../pkg/out/${p}_255.4-1ubuntu8.20_*.deb data/test/
done
ls data/test | wc -l
xorriso -as mkisofs -o data.iso -V DATA -J -r data > /dev/null 2>&1
ls -l data.iso
cp --reflink=auto noble-server-cloudimg-amd64.img work.img
qemu-img resize work.img 8G
dd if=/dev/zero of=results.img bs=1M count=64 2> /dev/null
ls -l work.img results.img

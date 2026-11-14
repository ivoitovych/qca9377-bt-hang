#!/bin/bash
# BlueZ doc/tester.config kernels: patched (co44) and base (co44^), as the dossier built them.
set -eu
W=/root/exp/agent-work/co44-send-20261113
L=$W/linux
K=$W/kernels
mkdir -p $K
git -C $L checkout -q co44
cp $W/bluez/doc/tester.config $L/.config
make -C $L olddefconfig > $W/logs/kernel-olddefconfig.log 2>&1
make -C $L -j16 > $W/logs/kernel-build-patched.log 2>&1
cp $L/arch/x86/boot/bzImage $K/bzImage-patched
cp $L/.config $K/config-patched
git -C $L rev-parse HEAD > $K/commit-patched
git -C $L checkout -q --detach co44^
make -C $L -j16 > $W/logs/kernel-build-base.log 2>&1
cp $L/arch/x86/boot/bzImage $K/bzImage-base
cp $L/.config $K/config-base
git -C $L rev-parse HEAD > $K/commit-base
git -C $L checkout -q co44
sha256sum $K/bzImage-base $K/bzImage-patched > $K/SHA256SUMS
echo done > $K/BUILD-DONE

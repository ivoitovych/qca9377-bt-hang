#!/bin/bash
# S1: fresh machine, kernel 7.0.0-38 installed by apt (real dpkg scripts, hook active, network on,
# empty cache). 38's stock btusb lacks the entry -> the hook must build E3 for it. This kernel
# becomes the "last kernel known to have E3" of the later scenarios.
exec > /out/s1-install-38.log 2>&1
. /w/tests/lib.sh
base_setup
say "seed the source cache for 38 (the archive no longer lists 38's source; files verified against the .dsc)"
S=/proj/cache/ubuntu-src
python3 -I /w/tests/seed-tree.py linux-hwe-7.0 7.0.0-38.38~24.04.4 "$S/linux-hwe-7.0_7.0.0-38.38~24.04.4.dsc" "$S/linux-hwe-7.0_7.0.0-38.38~24.04.4.diff.gz" /w/linux-hwe-7.0_7.0.0.orig.tar.gz
say "run-parts order of the three hook dirs (what runs before/after 50-btusb-e3)"
for d in postinst.d header_postinst.d postrm.d; do echo "-- /etc/kernel/$d"; run-parts --test /etc/kernel/$d; done
say "install linux-image + linux-headers 7.0.0-38 (BTUSB_E3_RUNNING=$BTUSB_E3_RUNNING)"
kinst linux-image-7.0.0-38-generic linux-headers-7.0.0-38-generic
kstate 7.0.0-38-generic
grubstate
initrdstate 7.0.0-38-generic
hooklog

#!/bin/bash
# S2 (docker --network none; image = after S1): the new kernel 7.0.0-42 is installed but the source
# cannot be fetched. Expect: apt exit 0 and packages "ii", hook logs FAILED, default boot entry pinned
# to 7.0.0-38 in the regenerated grub.cfg, STATUS shows the record.
exec > /out/s2-install-42-nonet.log 2>&1
. /w/tests/lib.sh
base_setup
say "network check (must fail)"
python3 -I -c "import urllib.request; urllib.request.urlopen('https://archive.ubuntu.com/ubuntu/dists/noble/InRelease', timeout=10)" 2>&1 | tail -1
say "install linux-image + linux-headers 7.0.0-42 without network"
kinst linux-image-7.0.0-42-generic linux-headers-7.0.0-42-generic
say "package state"
dpkg -l linux-image-7.0.0-42-generic linux-headers-7.0.0-42-generic | tail -2
kstate 7.0.0-42-generic
grubstate
initrdstate 7.0.0-42-generic
hooklog
say "retry offline: must stay failed, no change"
btusb-e3 retry
btusb-e3 status

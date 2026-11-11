#!/bin/bash
# S5 (network on; image = after S1): the entry patch does not apply to the kernel's btusb.c (the
# patch file is replaced with one whose context line no longer matches; stands for a future kernel
# whose table changed). Expect: record "failed", pin to 38, apt exit 0. Then the real patch is
# restored and the retry succeeds.
exec > /out/s5-patch-fails.log 2>&1
. /w/tests/lib.sh
base_setup
cp /usr/local/lib/btusb-e3/entry-dc16388d45ec.patch /tmp/good.patch
sed 's/0x3501/0x3599/g' /tmp/good.patch > /tmp/bad.patch
diff /tmp/good.patch /tmp/bad.patch
export BTUSB_E3_PATCH=/tmp/bad.patch
say "install 42 with the non-applying patch"
kinst linux-image-7.0.0-42-generic linux-headers-7.0.0-42-generic
dpkg -l linux-image-7.0.0-42-generic | tail -1
kstate 7.0.0-42-generic
grubstate
hooklog
say "restore the real patch, retry"
unset BTUSB_E3_PATCH
btusb-e3 run 7.0.0-42-generic
echo "run exit code: $?"
kstate 7.0.0-42-generic
grubstate

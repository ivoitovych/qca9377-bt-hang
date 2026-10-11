#!/bin/bash
# Build the bzImage the bot's TestRunner and TestFunctional use: bluetooth-next
# master with BlueZ's doc/tester.config (pytest-bluezenv build_kernel.py does
# the same: copy tester.config, make olddefconfig, make -j).
R=/home/user/qca9377-bt-hang
K=$R/cache/bluetooth-next
LOG=$R/tmp/ci-local-research/tester-kernel-build.log
cp $R/cache/bluez/doc/tester.config $K/.config
{ echo "tree: $(git -C $K log -1 --format='%H %s')"; echo "config: cache/bluez/doc/tester.config from $(git -C $R/cache/bluez log -1 --format=%h)"; date -u; } > $LOG
nice -n 19 make -C $K olddefconfig >> $LOG 2>&1
nice -n 19 make -C $K -j4 bzImage >> $LOG 2>&1
echo "kernel make rc=$?" >> $LOG
date -u >> $LOG
ls -la $K/arch/x86/boot/bzImage >> $LOG 2>&1

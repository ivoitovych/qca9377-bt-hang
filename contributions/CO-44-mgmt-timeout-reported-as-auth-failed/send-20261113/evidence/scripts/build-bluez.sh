#!/bin/bash
# Build BlueZ (the co44-test branch: master + the test) as the dossier did.
set -eu
W=/root/exp/agent-work/co44-send-20261113
cd $W/bluez
git log -1 --format='building %H %s' > $W/logs/bluez-build.log
./bootstrap-configure --disable-lsan >> $W/logs/bluez-build.log 2>&1
make -j16 >> $W/logs/bluez-build.log 2>&1
echo "build done" >> $W/logs/bluez-build.log

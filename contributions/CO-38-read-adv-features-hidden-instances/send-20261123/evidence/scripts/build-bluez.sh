#!/bin/bash
# build-bluez.sh : build the BlueZ worktree (master + CO-44's test + CO-38's new test) for the testers
set -u
W=${KQ_WORK:?set KQ_WORK to the work area (worktree, images, logs)}
cd "$W/bluez" || exit 2
mkdir -p "$W/logs"
git log -3 --format='%H %s' > "$W/logs/bluez-build.log"
nice -n 19 ionice -c 3 ./bootstrap-configure --disable-lsan >> "$W/logs/bluez-build.log" 2>&1 || { echo "configure failed" >> "$W/logs/bluez-build.log"; exit 1; }
nice -n 19 ionice -c 3 make -j4 >> "$W/logs/bluez-build.log" 2>&1
rc=$?
echo "bluez make rc=$rc" >> "$W/logs/bluez-build.log"
echo "$(date -u '+%F %T') UTC bluez build rc=$rc" >> "$W/progress.log"
exit $rc

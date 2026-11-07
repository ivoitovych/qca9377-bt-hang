#!/bin/sh
# Build the image. Run from anywhere; uses absolute paths.
A=/root/exp/agent-work/u29-g1-gnome-pairing-feedback
echo "$(date +%H:%M:%S) build start" >> $A/PROGRESS.log
docker build --pull -f $A/docker/Dockerfile -t u29-gnome-bluetooth:master $A > $A/runs/build.log 2>&1
rc=$?
echo "$(date +%H:%M:%S) build end rc=$rc" >> $A/PROGRESS.log
exit $rc

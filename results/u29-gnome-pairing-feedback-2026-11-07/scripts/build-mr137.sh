#!/bin/sh
# Second image: same Dockerfile, MR 137 diff applied unedited to the copy of the source.
A=/root/exp/agent-work/u29-g1-gnome-pairing-feedback
echo "$(date +%H:%M:%S) build-mr137 start" >> $A/PROGRESS.log
docker build --build-arg APPLY_DIFF=yes -f $A/docker/Dockerfile -t u29-gnome-bluetooth:mr137 $A > $A/runs/build-mr137.log 2>&1
rc=$?
echo "$(date +%H:%M:%S) build-mr137 end rc=$rc" >> $A/PROGRESS.log
exit $rc

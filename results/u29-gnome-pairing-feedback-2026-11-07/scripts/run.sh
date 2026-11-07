#!/bin/sh
# Run the test in the container. Default network, no extra capabilities, no host sockets.
A=/root/exp/agent-work/u29-g1-gnome-pairing-feedback
echo "$(date +%H:%M:%S) run start" >> $A/PROGRESS.log
docker run --rm -v $A/runs/out:/out -v $A/tests:/work/tests:ro u29-gnome-bluetooth:master sh /work/tests/in-container.sh > $A/runs/run.log 2>&1
rc=$?
echo "$(date +%H:%M:%S) run end rc=$rc" >> $A/PROGRESS.log
exit $rc

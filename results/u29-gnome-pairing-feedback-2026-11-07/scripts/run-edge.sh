#!/bin/sh
# usage: run-edge.sh IMAGE_TAG OUTSUBDIR SCENARIO ERROR REPEAT
# e.g.   run-edge.sh mr137 edge/mr137-remove-failed remove AuthenticationFailed 3
A=/root/exp/agent-work/u29-g1-gnome-pairing-feedback
mkdir -p $A/runs/$2
echo "$(date +%H:%M:%S) run-edge $1 $3 $4 start" >> $A/PROGRESS.log
docker run --rm -e SCENARIO=$3 -e ERROR=$4 -e REPEAT=$5 -v $A/runs/$2:/out -v $A/tests:/work/tests:ro u29-gnome-bluetooth:$1 sh /work/tests/in-container-edge.sh > $A/runs/$2.log 2>&1
rc=$?
echo "$(date +%H:%M:%S) run-edge $1 $3 $4 end rc=$rc" >> $A/PROGRESS.log
exit $rc

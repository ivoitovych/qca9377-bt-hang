#!/bin/sh
# usage: run-mr137.sh IMAGE_TAG OUTSUBDIR ERRORS_COMMA_LIST CONTROL(0|1)
# e.g.   run-mr137.sh mr137 out-mr137 AuthenticationRejected,AuthenticationFailed,AuthenticationCanceled 1
A=/root/exp/agent-work/u29-g1-gnome-pairing-feedback
mkdir -p $A/runs/$2
echo "$(date +%H:%M:%S) run-mr137 $1 start" >> $A/PROGRESS.log
docker run --rm -e ERRORS=$3 -e CONTROL=$4 -v $A/runs/$2:/out -v $A/tests:/work/tests:ro u29-gnome-bluetooth:$1 sh /work/tests/in-container-mr137.sh > $A/runs/$2.log 2>&1
rc=$?
echo "$(date +%H:%M:%S) run-mr137 $1 end rc=$rc" >> $A/PROGRESS.log
exit $rc

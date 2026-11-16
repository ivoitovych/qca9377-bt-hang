#!/bin/bash
# the container half again (the first attempt lost its OUT variable): queries, then the -g subset runs
B=$WORKDIR/bin
$B/run-queries.sh container
export QONLY="-g rare word" GK=25 UNIT=systemd-logind.service
DKOPTS="-v /var/log/journal:/rj:ro -e W=/work -e ENVNAME=container -e REALGLOB=/rj/*/ -e OUT=/work/results-queries-g25.tsv" WHAT=real $B/dk.sh query-runs.sh
DKOPTS="-e W=/work -e ENVNAME=container -e OUT=/work/results-queries-g25.tsv" WHAT=synth SYNTHK=25 $B/dk.sh query-runs.sh
echo REST2DONE

#!/bin/bash
# run-queries.sh host|container : the common queries, a and b, on the real journal (all files) and the 800-file synthetic set.
# One run at a time. Host: from the work dir's bins/. Container: same bins through the read-only journal mount.
B=$WORKDIR
mode=$1
export UNIT=${UNIT:-systemd-logind.service}
if [ "$mode" = host ]; then
    export W=$B ENVNAME=host REALGLOB='/var/log/journal/*/' OUT=$B/results-queries-host.tsv
    for what in ${WHATS:-synth real}; do
        WHAT=$what nice -n 19 ionice -c 3 $B/bin/query-runs.sh
    done
else
    export DKOPTS="-v /var/log/journal:/rj:ro -e W=/work -e ENVNAME=container -e REALGLOB=/rj/*/ -e OUT=/work/results-queries-container.tsv"
    for what in ${WHATS:-synth real}; do
        WHAT=$what $B/bin/dk.sh query-runs.sh
    done
fi
echo QUERIESDONE $mode

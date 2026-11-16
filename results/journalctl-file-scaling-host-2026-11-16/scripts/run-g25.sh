#!/bin/bash
# The -g full scan on the newest 25 files of the real journal and on the 25-file synthetic set (a finishes
# in seconds there), host and container. One run at a time.
B=$WORKDIR
export QONLY="-g rare word" GK=25 UNIT=systemd-logind.service
export W=$B ENVNAME=host REALGLOB='/var/log/journal/*/' OUT=$B/results-queries-g25.tsv
WHAT=real nice -n 19 ionice -c 3 $B/bin/query-runs.sh
WHAT=synth SYNTHK=25 nice -n 19 ionice -c 3 $B/bin/query-runs.sh
unset W ENVNAME REALGLOB OUT
DKOPTS="-v /var/log/journal:/rj:ro -e W=/work -e ENVNAME=container -e REALGLOB=/rj/*/ -e OUT=/work/results-queries-g25.tsv" WHAT=real $B/bin/dk.sh query-runs.sh
DKOPTS="-e W=/work -e ENVNAME=container -e OUT=/work/results-queries-g25.tsv" WHAT=synth SYNTHK=25 $B/bin/dk.sh query-runs.sh
echo G25DONE

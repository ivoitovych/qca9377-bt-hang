#!/bin/bash
# Bare host, outside any container. Builds run from the work dir's bins/, nothing installed.
# One run at a time, lowest priority.
export W=$WORKDIR
export ENVNAME=host
export REALGLOB='/var/log/journal/*/'
export OUT=$W/results-host.tsv
M=$W/bin/measure-runs.sh
WHAT=synth nice -n 19 ionice -c 3 $M
WHAT=real nice -n 19 ionice -c 3 $M
echo HOSTDONE

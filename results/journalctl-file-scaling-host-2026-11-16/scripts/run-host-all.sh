#!/bin/bash
# Re-run of the host's K=all rows (the first attempt used a file list that the live journal had changed under it).
export W=$WORKDIR ENVNAME=host REALGLOB='/var/log/journal/*/'
export OUT=$W/results-host-all.tsv WHAT=real KS=all
nice -n 19 ionice -c 3 $W/bin/measure-runs.sh
echo HOSTALLDONE

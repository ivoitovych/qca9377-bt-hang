#!/bin/bash
# run-to-file.sh <output file> <command> [args...]
# Runs the command with stdout and stderr into the output file, and appends
# start and end lines (clock range "HH:MM:SS to HH:MM:SS") to progress.log.
set -u
out="$1"
shift
log=/root/exp/agent-work/laptop-btusb-modules-20261111/progress.log
start=$(date '+%H:%M:%S')
echo "$(date '+%Y-%m-%d') $start START $out: $*" >>"$log"
"$@" >"$out" 2>&1
rc=$?
end=$(date '+%H:%M:%S')
echo "$(date '+%Y-%m-%d') $end END rc=$rc $out ($start to $end)" >>"$log"
exit $rc

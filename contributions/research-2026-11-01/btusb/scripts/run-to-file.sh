#!/bin/bash
# run-to-file.sh <output file> <command> [args...]
# Runs the command with stdout and stderr into the output file, and appends
# start and end lines to the work area's progress.log.
set -u
out="$1"
shift
log=/root/exp/agent-work/research-btusb/progress.log
echo "$(date '+%Y-%m-%d %H:%M:%S') START $out: $*" >>"$log"
"$@" >"$out" 2>&1
rc=$?
echo "$(date '+%Y-%m-%d %H:%M:%S') END rc=$rc $out" >>"$log"
exit $rc

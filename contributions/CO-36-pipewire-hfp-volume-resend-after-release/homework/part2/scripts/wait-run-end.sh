#!/bin/sh
# Returns when the progress log has an "end" line for the given run id
# (so a background call notifies once the run is over).
# Usage: wait-run-end.sh <run id>
until grep -q " $1 end rc=" /root/exp/agent-work/co36/progress.log; do
    sleep 5
done
grep " $1 end rc=" /root/exp/agent-work/co36/progress.log

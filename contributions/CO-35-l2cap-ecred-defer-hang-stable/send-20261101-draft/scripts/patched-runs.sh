#!/bin/bash
# patched-runs.sh <tag> <variant> : the case alone (180 s) then the unfiltered l2cap-tester (900 s) on img/bzImage-<tag>-<variant>.
set -u
TAG=${1:?usage}; V=${2:?usage}
W=/root/exp/agent-work/co35/refresh-20261101
I=$W/img/bzImage-$TAG-$V
"$W/run-test.sh" "$I" "$W/logs/case-$TAG-$V.log" 180 exact
"$W/run-test.sh" "$I" "$W/logs/full-$TAG-$V.log" 900 all

#!/bin/bash
# base-controls.sh <tag> [variant=base] : on the unpatched image img/bzImage-<tag>-<variant>: the unfiltered
# l2cap-tester (stops at the hanging case, 240 s limit) and the post-hang control words (PHY, Timestamping,
# Ethtool, PIN), 200 s each.
set -u
TAG=${1:?usage}; V=${2:-base}
W=/root/exp/agent-work/co35/refresh-20261101
I=$W/img/bzImage-$TAG-$V
"$W/run-test.sh" "$I" "$W/logs/full-$TAG-$V.log" 240 all
for w in PHY Timestamping Ethtool PIN; do
	"$W/run-test.sh" "$I" "$W/logs/word-$w-$TAG-$V.log" 200 "word:$w"
done

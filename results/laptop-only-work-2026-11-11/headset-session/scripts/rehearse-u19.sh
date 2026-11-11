#!/bin/sh
top=/root/exp/agent-work/laptop-headset-session-20261111
out=$top/logs/rehearse-u19
mkdir -p "$out"
"$top/scripts/log.sh" START rehearse-u19
docker run --rm \
  -v "$top/kit:/kit:ro" \
  -v "$top/scripts/in-container:/inc:ro" \
  -v "$out:/out" \
  ubuntu:24.04 sh /inc/u19-inner.sh
echo "docker exit $?" >> "$out/rehearsal.txt"
"$top/scripts/log.sh" END rehearse-u19

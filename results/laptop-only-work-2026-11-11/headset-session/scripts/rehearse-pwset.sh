#!/bin/sh
top=/root/exp/agent-work/laptop-headset-session-20261111
out=$top/logs/rehearse-pwset
mkdir -p "$out"
rm -f "$out/plugin-result.txt"
"$top/scripts/log.sh" START rehearse-pwset
docker run --rm \
  -v "$top/logs/build-pipewire-all/debs:/pw:ro" \
  -v "$top/kit:/kit:ro" \
  -v "$top/scripts/in-container:/inc:ro" \
  -v "$out:/out" \
  ubuntu:24.04 sh /inc/pwset-inner.sh
echo "docker exit $?" >> "$out/rehearsal.txt"
"$top/scripts/log.sh" END rehearse-pwset

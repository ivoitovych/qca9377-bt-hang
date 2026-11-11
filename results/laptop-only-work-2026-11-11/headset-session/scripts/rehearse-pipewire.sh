#!/bin/sh
# Rehearse the CO-19 pair install / restart / rollback in ubuntu:24.04 (no devices).
top=/root/exp/agent-work/laptop-headset-session-20261111
out=$top/logs/rehearse-pipewire
mkdir -p "$out"
"$top/scripts/log.sh" START rehearse-pipewire
docker run --rm \
  -v /root/exp/qca9377-bt-hang/tmp/co19-pipewire/out:/pw:ro \
  -v "$top/scripts/in-container:/inc:ro" \
  -v "$out:/out" \
  ubuntu:24.04 sh /inc/pw-inner.sh
echo "docker exit $?" >> "$out/rehearsal.txt"
"$top/scripts/log.sh" END rehearse-pipewire

#!/bin/sh
# Rebuild the CO-19 source package (all binary packages) in ubuntu:24.04. No devices.
top=/root/exp/agent-work/laptop-headset-session-20261111
out=$top/logs/build-pipewire-all
mkdir -p "$out"
"$top/scripts/log.sh" START build-pipewire-all
docker run --rm \
  -v /root/exp/qca9377-bt-hang/tmp/co19-pipewire:/w:ro \
  -v "$top/scripts/in-container:/inc:ro" \
  -v "$out:/o" \
  ubuntu:24.04 bash /inc/pw-build-all.sh > "$out/container.log" 2>&1
echo "docker exit $?" >> "$out/container.log"
"$top/scripts/log.sh" END build-pipewire-all

#!/bin/sh
# Rehearse the CO-03 package install / rollback in a throw-away ubuntu:24.04 container.
# No device is passed, no host path is writable except the log directory.
top=/root/exp/agent-work/laptop-headset-session-20261111
out=$top/logs/rehearse-bluez
mkdir -p "$out"
"$top/scripts/log.sh" START rehearse-bluez
docker run --rm \
  -v /root/exp/agent-work/co03/pkg:/pkg:ro \
  -v "$top/work/fixtures:/fx:ro" \
  -v "$top/kit:/kit:ro" \
  -v "$top/scripts/in-container:/inc:ro" \
  -v "$out:/out" \
  ubuntu:24.04 sh /inc/bluez-inner.sh
echo "docker exit $?" >> "$out/rehearsal.txt"
"$top/scripts/log.sh" END rehearse-bluez

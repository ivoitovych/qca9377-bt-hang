#!/bin/bash
# btmon width matrix, stock 5.72-0ubuntu5.8 btmon vs the bundle's btmon, replay of the two CO-11a captures,
# inside the noble build container (the binaries were built there by dpkg-buildpackage).
B=/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle
D=$B/btmon-replay
FIN=/root/exp/agent-work/co11a-ready-20261102/final
mkdir -p "$D/bin" "$D/caps" "$D/out"
cp "$B/tree-base/bluez-5.72/monitor/btmon" "$D/bin/btmon-stock"
cp "$B/tree/bluez-5.72/monitor/btmon" "$D/bin/btmon-patched"
cp "$FIN/lines.btsnoop" "$FIN/priv-open.btsnoop" "$D/caps/"
sed -e 's/^WIDTHS = .*/WIDTHS = [10, 40, 60, 79, 80, 81, 82, 100, 200, 3000, 5000, "piped"]/' /root/exp/agent-work/co11a-ready-20261102/scripts/replay2.py > "$D/replay2.py"
sha256sum "$D/bin/btmon-stock" "$D/bin/btmon-patched" "$D/caps/lines.btsnoop" "$D/caps/priv-open.btsnoop" > "$D/inputs.sha256"
docker run --rm -v "$B:/w" -w /w/btmon-replay co03-noble-build:1 sh -c \
  'python3 -I replay2.py noble-5.72 /w/btmon-replay/bin /w/btmon-replay/out /w/btmon-replay/caps/lines.btsnoop /w/btmon-replay/caps/priv-open.btsnoop; echo "replay exit $?"' > "$D/replay.log" 2>&1
tail -n 1 "$D/replay.log"

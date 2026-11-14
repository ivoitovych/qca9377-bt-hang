#!/bin/bash
T=/root/exp/agent-work/lane5-status-stable-20261114/task4
S=/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle/btmon-live
D=$T/live-vm
mkdir -p "$D/bin" "$D/jobs" "$D/out"
cp -a "$S/scripts" "$D/scripts"
cp -a "$S/archive-deb" "$D/archive-deb"
cp "$S/bin/spawnpid" "$S/bin/btvirt-stock" "$D/bin/"
for v in resolute-stock resolute-patched stonking-stock stonking-patched; do cp "$T/live/bin/btmon-$v" "$D/bin/btmon-$v"; done
sed -i "s#/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle/btmon-live#$D#g" "$D/scripts/vm.sh" "$D/scripts/log.sh"
echo '{"tag": "live-newer", "runs": 5, "variants": ["resolute-stock", "resolute-patched", "stonking-stock", "stonking-patched"], "widths": [60, 80, 100, 120, 200, "piped"], "opts": [[]], "scenarios": ["real", "long"]}' > "$D/jobs/live-newer.json"
grep -n "live-vm" "$D/scripts/vm.sh" "$D/scripts/log.sh"
ls -la "$D/bin"

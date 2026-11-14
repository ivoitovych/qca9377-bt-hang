#!/bin/bash
S=/root/exp/agent-work/co11a-live-20261102
D=/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle/btmon-live
cp -a "$S/scripts" "$D/scripts"
cp -a "$S/archive-deb" "$D/archive-deb"
cp -a "$S/jobs/live-default.json" "$D/jobs/"
echo copied

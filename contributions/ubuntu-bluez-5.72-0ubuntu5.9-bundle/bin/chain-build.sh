#!/bin/bash
B=/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle
$B/bin/exit-build.sh master
$B/bin/exit-build.sh 572 e572base "$B/fresh/base/bluez-5.72"
$B/bin/exit-build.sh 572 e572bundle "$B/fresh/bundle/bluez-5.72"
echo "CHAIN-BUILD-DONE $(date -u '+%F %T') UTC" >> "$B/logs/progress.log"

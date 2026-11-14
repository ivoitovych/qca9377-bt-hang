#!/bin/bash
T=/root/exp/agent-work/lane5-status-stable-20261114/task4
W=$T/work
say() { echo "$(date -u '+%F %T') UTC $*" | tee -a "$T/logs/progress.log"; }
chmod +x "$W/scripts/inner-build.sh"
say "start resolute 5.85-4ubuntu0.6"
docker run --rm --cpus 4 -v "$W:/w" ubuntu:26.04 /w/scripts/inner-build.sh resolute bluez_5.85-4ubuntu0.5.dsc 5.85-4ubuntu0.6 bluez_5.85.orig.tar.gz > "$W/logs/build-resolute.log" 2>&1
say "end resolute rc=$?"
say "start stonking 5.87-4ubuntu0.2"
docker run --rm --cpus 4 -v "$W:/w" ubuntu:26.10 /w/scripts/inner-build.sh stonking bluez_5.87-4ubuntu0.1.dsc 5.87-4ubuntu0.2 bluez_5.87.orig.tar.gz > "$W/logs/build-stonking.log" 2>&1
say "end stonking rc=$?"
say "NEWER-DONE"

#!/bin/bash
# user-audio-streams.sh — who is using which audio device right now, read-only.
#
#   scripts/user-audio-streams.sh
#
# Runs `pw-dump` as the desktop user (default `i`; BT_DESKTOP_USER overrides) and summarises it
# with user-audio-streams.py: each Bluetooth card's active profile, then every stream node
# (recording or playback) with its application, media name, process id, state and target.
# pw-dump only reads the PipeWire graph; it changes nothing and sends nothing to the controller.
#
# WHY (2026-10-29, U21): the Shure stayed in Handsfree while the operator saw a grey "Claude"
# microphone indicator; the question was which program still held the headset's microphone.
set -uo pipefail
U="${BT_DESKTOP_USER:-i}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UID_N="$(id -u "$U")"
runuser -u "$U" -- env XDG_RUNTIME_DIR="/run/user/$UID_N" pw-dump 2>/dev/null | python3 -I "$HERE/user-audio-streams.py"

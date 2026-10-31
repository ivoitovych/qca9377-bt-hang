#!/bin/bash
# user-pw-dump.sh — save the desktop user's whole PipeWire graph, read-only.
#
#   scripts/user-pw-dump.sh <output file>
#
# Runs `pw-dump` as the desktop user (default `i`; BT_DESKTOP_USER overrides) and writes its
# JSON to <output file>: every card with its EnumProfile/EnumRoute/Route params, every node
# and link. pw-dump only reads the graph; it changes nothing and sends nothing to the controller.
# The output holds device addresses: keep it local (archive/ or tmp/), never in a public file.
#
# WHY (2026-10-31): GNOME Settings listed only "Handsfree - MOMENTUM 4" as output, no
# headphones entry; the cards' profiles and routes at that moment are the evidence, and
# user-audio-streams.sh keeps only its summary.
set -uo pipefail
out="${1:?usage: user-pw-dump.sh <output file>}"
U="${BT_DESKTOP_USER:-i}"
UID_N="$(id -u "$U")"
runuser -u "$U" -- env XDG_RUNTIME_DIR="/run/user/$UID_N" pw-dump > "$out"
echo "wrote $(wc -c < "$out") bytes to $out"

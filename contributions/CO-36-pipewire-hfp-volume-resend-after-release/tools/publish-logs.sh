#!/bin/bash
# Copies tmp/co36/raw/* into the CO-36 package through the public placeholder tool
# (tools/sanitize-logs.sh: AA:BB:CC:00:00:NN per file), drops btmon's "(OUI xx-xx-xx)" note for
# the second headset (its address is not a registered manufacturer prefix), and runs the
# publish scan on the result.
set -u
P=/root/exp/qca9377-bt-hang
OUT=$P/contributions/CO-36-pipewire-hfp-volume-resend-after-release/logs
mkdir -p "$OUT"
for f in "$P"/tmp/co36/raw/*; do
	o=$OUT/$(basename "$f")
	[[ -e "$o" ]] && { echo "exists, not overwritten: $o"; continue; }
	"$P/tools/sanitize-logs.sh" "$f" "$o" || exit 1
	sed -i 's/(OUI [0-9A-Fa-f][0-9A-Fa-f]-[0-9A-Fa-f][0-9A-Fa-f]-[0-9A-Fa-f][0-9A-Fa-f])/(OUI removed)/g' "$o"
done
python3 -I /root/exp/privacy-instructions/addr-pseudonym.py check /root/exp/privacy-instructions/PRIVACY-INSTRUCTIONS.md "$OUT"

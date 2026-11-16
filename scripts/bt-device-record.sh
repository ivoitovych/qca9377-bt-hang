#!/bin/bash
# bt-device-record.sh — what bluetoothd stored about a device, WITHOUT its keys or address.
#
#   bt-device-record.sh <name regex>     e.g. bt-device-record.sh 'Tronsmart|T8'
#
# Prints, for each stored device whose Name= matches (case-insensitive), only the
# lines Name, Alias, Class, Icon, Appearance, Services, SupportedTechnologies of its
# `info` file. /var/lib/bluetooth also holds link keys and long-term keys; they are
# never read into the output: the field filter is a fixed allow-list, and the address
# (the directory name) is not printed. Read-only.
set -u
[[ $# -eq 1 && -n "$1" ]] || { sed -n '2,10p' "$0" >&2; exit 2; }
want=$1
STORE="${BT_BLUEZ_STORE:-/var/lib/bluetooth}"   # a seam, so a test never reads the real store
found=0; readable=0; unreadable=0
for f in "$STORE"/*/*/info; do
	[[ -e "$f" ]] || continue
	[[ -r "$f" ]] || { unreadable=$((unreadable + 1)); continue; }
	readable=$((readable + 1))
	name=$(grep -m1 '^Name=' "$f") || continue
	grep -qiE -- "$want" <<<"${name#Name=}" || continue
	found=$((found + 1))
	echo "== device $found"
	grep -E '^(Name|Alias|Class|Icon|Appearance|Services|SupportedTechnologies)=' "$f"
done
# The store itself not being readable (no root, no such directory) is not "no
# stored device": exit 2, and say that nothing was looked at.
if (( ! readable )); then
	echo "NOT LOOKED AT: no readable device record under $STORE ($unreadable unreadable; root is needed to read it)" >&2; exit 2
fi
(( found )) || { echo "no stored device matches: $want (looked at $readable record(s)$( (( unreadable )) && echo ", $unreadable unreadable and NOT looked at"))" >&2; exit 1; }
(( unreadable == 0 )) || echo "note: $unreadable record(s) were unreadable and NOT looked at" >&2

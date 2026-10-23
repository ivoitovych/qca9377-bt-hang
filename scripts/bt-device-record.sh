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
found=0
for f in /var/lib/bluetooth/*/*/info; do
	[[ -r "$f" ]] || continue
	name=$(grep -m1 '^Name=' "$f") || continue
	grep -qiE -- "$want" <<<"${name#Name=}" || continue
	found=$((found + 1))
	echo "== device $found"
	grep -E '^(Name|Alias|Class|Icon|Appearance|Services|SupportedTechnologies)=' "$f"
done
(( found )) || { echo "no stored device matches: $want" >&2; exit 1; }

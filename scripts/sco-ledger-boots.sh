#!/bin/bash
# sco-ledger-boots.sh — scripts/sco-ledger.sh over several boots, then the
# totals across them: links, hang-ups answered, timeouts, and links per headset.
# For an aggregate that an exhibit can carry as one command (E1: three boots).
#
#   scripts/sco-ledger-boots.sh <boot>...      boot indices or ids, as journalctl -b takes them
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
(( $# )) || { echo "usage: sco-ledger-boots.sh <boot>..." >&2; exit 2; }
TMP=$(mktemp) || exit 1
trap 'rm -f "$TMP"' EXIT
for b in "$@"; do
	echo "== boot $b"
	"$HERE/sco-ledger.sh" "$b" | tee -a "$TMP"
	echo
done
awk '
/^links / { links += $2; ok += $5; to += $7; next }
/^setup/ || /^$/ { next }
{ n = NF; if ($n ~ /^ms$/ || $n ~ /^open$/ || $(n-1) == "TIMEOUT") { } }
/hangup-ok|TIMEOUT|open$/ {
	# the headset name is everything between the timestamp and the air column
	name = ""; for (i = 2; i <= NF; i++) { if ($i == "msbc" || $i == "cvsd" || $i == "?") break; name = name (name ? " " : "") $i }
	per[name]++
}
END {
	printf "TOTAL over %d boot(s): links %d   hang-ups answered %d   timeouts %d\n", boots, links, ok, to
	for (h in per) printf "  %-24s %d\n", h, per[h]
}' boots="$#" "$TMP"

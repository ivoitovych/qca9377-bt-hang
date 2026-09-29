#!/bin/bash
# capture-window.sh — the decoded packets of one btsnoop capture inside a time
# window, optionally only the packets whose decoded text matches a pattern.
# For reading an HFP codec switch (RFCOMM AT+BCS / +BCS), a SCO setup or a
# failure minute without paging through hours of decode.
#
#   scripts/capture-window.sh <capture.btsnoop> <from> <to> [<ere>]
#       from/to as "2026-09-29 02:30:40" (local time, as btmon -T prints it)
#       ere: keep only packets whose block matches, e.g. 'RFCOMM|[+]BCS|Synchronous|Air mode|Disconnect'
#            (awk ERE: write a literal plus as [+]; "SCO" alone matches every SCO Data packet)
#
# Read-only. btmon at COLUMNS=160 (btmon 5.72 overflows a fixed buffer on
# terminals wider than 255 columns). A packet is btmon's header line
# ("< HCI Command", "> HCI Event", "> ACL Data", "@ MGMT", "= …") with the
# timestamp at its end, plus its indented continuation lines.
set -uo pipefail
FILE="${1:?usage: capture-window.sh <capture.btsnoop> <from> <to> [<ere>]}"
FROM="${2:?from}"; TO="${3:?to}"; ERE="${4:-}"
[[ -r "$FILE" ]] || { echo "cannot read $FILE" >&2; exit 2; }
COLUMNS=160 btmon -T -r "$FILE" 2>/dev/null | awk -v from="$FROM" -v to="$TO" -v ere="$ERE" '
function flush() { if (keep && (ere == "" || blk ~ ere)) printf "%s", blk; blk = ""; keep = 0 }
/^[<>@=]/ {
	flush()
	ts = $(NF-1) " " $NF
	keep = (ts >= from && ts <= to)
	if (ts > to) { exit }
}
{ if (keep) blk = blk $0 "\n" }
END { flush() }'

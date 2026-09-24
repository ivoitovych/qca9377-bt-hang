#!/bin/bash
# mgmt-replies.sh — every management-channel reply in btsnoop captures: time,
# capture, event kind (Command Status / Command Complete), the command it
# answers, and the status byte, with per-file totals. Read-only; decodes
# with btmon, which aborts on some captures (BT-4) — an abort is reported per
# file, never read as "no replies".
#
#   scripts/mgmt-replies.sh <capture.btsnoop>...           all replies
#   BT_MGMT_ONLY="Discovery" scripts/mgmt-replies.sh …      only commands matching
set -uo pipefail
#   scripts/mgmt-replies.sh --status --since "2026-09-24 01:18" [--trace]
#       every capture file written since then (capture/ by default, --trace
#       for the btmon trace), Command Status only — no file list, no env prefix
ONLY="${BT_MGMT_ONLY:-}"
KIND="${BT_MGMT_KIND:-}"      # STATUS or COMPLETE to keep only that event kind
SINCE=""; DIR=/var/log/bt-health/capture
while [[ "${1:-}" == --* ]]; do
	case "$1" in
		--status)   KIND=STATUS ;;
		--complete) KIND=COMPLETE ;;
		--only)     ONLY="${2:?--only needs a regex}"; shift ;;
		--since)    SINCE="${2:?--since needs a time}"; shift ;;
		--trace)    DIR=/var/log/bt-health/trace ;;
		*) echo "unknown option $1" >&2; exit 2 ;;
	esac
	shift
done
if [[ -n "$SINCE" ]]; then
	mapfile -t FILES < <(find "$DIR" -name '*.btsnoop' -newermt "$SINCE" | sort)
	(( ${#FILES[@]} )) || { echo "no captures in $DIR since $SINCE" >&2; exit 1; }
	set -- "${FILES[@]}" "$@"
fi
(( $# )) || { echo "usage: mgmt-replies.sh [--status|--complete] [--only RE] [--since TIME [--trace]] [capture.btsnoop...]" >&2; exit 2; }
for f in "$@"; do
	out=$(COLUMNS=200 btmon -T -r "$f" 2>/dev/null); brc=$?
	(( brc == 0 )) || echo "!! $(basename "$f"): btmon exited $brc — decode incomplete (BT-4)"
	awk -v cap="$(basename "$f")" -v only="$ONLY" -v kindf="$KIND" '
		BEGIN {
			OP["0005"]="Set Powered"; OP["0006"]="Set Discoverable"; OP["0007"]="Set Connectable"
			OP["0023"]="Start Discovery"; OP["0024"]="Stop Discovery"; OP["003a"]="Start Service Discovery"
			OP["0019"]="Pair Device"; OP["001b"]="Unpair Device"; OP["0009"]="Set Bondable"
			ST["00"]="Success"; ST["0b"]="Rejected"; ST["0a"]="Busy"; ST["0f"]="Not Powered"
			ST["11"]="Invalid Index"; ST["0d"]="Invalid Parameters"; ST["03"]="Failed"
		}
		# btmon truncates names to the terminal ("Command Co.."), so match the
		# event CODE: 0x0001 Command Complete, 0x0002 Command Status
		# (down to "Com.." or "C.." on long lines — the name cannot be matched at all)
		/^@ MGMT Event: [^(]*\(0x000[12]\) plen/ {
			kind = ($0 ~ /\(0x0002\)/) ? "STATUS  " : "COMPLETE"
			ts = $(NF-1) " " $NF; want = 2; cmd = ""; next
		}
		# In a capture file that starts after a rotation btmon has not seen the
		# sockets open and prints management frames UNDECODED:
		#   @ Control Event: 0xffff   {0x0001} [hci0] 2026-08-14 21:03:26.994426
		#           02 00 23 00 00          (event LE, opcode LE, status)
		# (the layout tools/bt-ctrl-window decodes, EX-044). Read those too, or a
		# rotated file reads as "no replies" — which it did, 2026-09-24.
		/^@ Control Event:/ { ts = $(NF-1) " " $NF; raw = 1; next }
		raw == 1 {
			raw = 0; nb = split($0, b, /[ \t]+/); i = 1; while (i <= nb && b[i] == "") i++
			code = tolower(b[i+1] b[i])
			if (code != "0001" && code != "0002") next
			kind = (code == "0002") ? "STATUS  " : "COMPLETE"
			opc = tolower(b[i+3] b[i+2]); s = tolower(b[i+4])
			nm = (opc in OP) ? OP[opc] : "opcode"
			cmd = nm " (0x" opc ")"; st = "0x" s ((s in ST) ? " " ST[s] : "")
			n[kind]++
			if ((only == "" || cmd ~ only) && (kindf == "" || index(kind, kindf) == 1)) printf "%s  %-26s %s  %-40s %s  [raw]\n", ts, cap, kind, cmd, st
			next
		}
		want == 2 { cmd = $0; sub(/^ +/, "", cmd); sub(/ plen.*/, "", cmd); want = 1; next }
		want == 1 && /Status:/ {
			st = $0; sub(/^ +Status: /, "", st)
			n[kind]++
			if ((only == "" || cmd ~ only) && (kindf == "" || index(kind, kindf) == 1)) printf "%s  %-26s %s  %-40s %s\n", ts, cap, kind, cmd, st
			want = 0
		}
		END { printf "## %s: %d Command Complete, %d Command Status\n", cap, n["COMPLETE"], n["STATUS  "] }
	' <<<"$out"
done

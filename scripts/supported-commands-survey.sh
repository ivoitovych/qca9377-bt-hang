#!/bin/bash
# supported-commands-survey.sh — what the controller advertised in every
# retained capture: for each Read Local Supported Commands reply, the entry
# count and whether Enhanced Setup / Enhanced Accept Synchronous Connection
# (octet 29 bits 3 and 4) are listed.
#
#   scripts/supported-commands-survey.sh [capture-dir]   default /var/log/bt-health/capture
#
# WHY. The kernel sets up SCO with Enhanced 0x043D only when the controller
# advertises it (hci_core.h enhanced_sync_conn_capable: commands[29] & 0x08)
# and no quirk forbids it. EX-031 (08-18) got 0x043D and survived ~17 min on
# alt 1; all twelve deaths got legacy 0x0428. On 2026-09-25 the controller
# listed 197 commands without Enhanced Setup. If what it advertises differs
# from boot to boot, its firmware state differs too.
#
# Output: tmp/supported-commands-survey.tsv, one row per reply:
#   file  reply-time  entries  enhanced_setup  enhanced_accept
# Read-only; btmon at COLUMNS=160 (btmon 5.72 overflows a fixed buffer on
# terminals wider than 255 columns).
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="${1:-/var/log/bt-health/capture}"
OUT="$REPO/tmp/supported-commands-survey.tsv"
command -v btmon >/dev/null || { echo "btmon not found" >&2; exit 2; }
[[ -d "$DIR" ]] || { echo "no capture directory: $DIR" >&2; exit 2; }
printf 'file\treply_time\tentries\tenhanced_setup\tenhanced_accept\n' > "$OUT"
n=0
for f in "$DIR"/*.btsnoop; do
	[[ -e "$f" ]] || continue
	COLUMNS=160 btmon -T -r "$f" 2>/dev/null | awk -v file="$(basename "$f")" '
		# btmon puts the opcode of a Command Complete on the indented line
		# below the "> HCI Event:" header, which carries the timestamp.
		inreply && /^[<>@=]/ { printf "%s\t%s\t%s\t%s\t%s\n", file, ts, entries, es, ea; inreply = 0 }
		/^> HCI Event/ { evts = $(NF-1) "T" $NF }
		/^ +Read Local Supported Commands \(0x04\|0x0002\) ncmd/ { inreply = 1; ts = evts; entries = "?"; es = "no"; ea = "no"; next }
		inreply && /Commands: [0-9]+ entr/ { entries = $2 }
		inreply && /Enhanced Setup Synchronous Connection/ { es = "yes" }
		inreply && /Enhanced Accept Synchronous Connection/ { ea = "yes" }
		END { if (inreply) printf "%s\t%s\t%s\t%s\t%s\n", file, ts, entries, es, ea }
	' >> "$OUT"
	n=$((n + 1))
done
echo "scanned $n capture file(s); replies found: $(( $(wc -l < "$OUT") - 1 ))"
echo "-> $OUT"
column -t -s $'\t' "$OUT"

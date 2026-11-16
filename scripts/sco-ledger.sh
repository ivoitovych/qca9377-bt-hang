#!/bin/bash
# sco-ledger.sh — one row per SCO link in a boot's kernel log: which headset,
# air mode, alt-1 traffic, how long it streamed, and how the first command
# after it fared (the BT-1 question). For counting E1 (and later builds)
# against the stock driver's 12/12 deaths without hand-counting journal lines.
#
#   scripts/sco-ledger.sh [<boot>]      boot index or id; default 0
#
# Needs the btusb/hci debug lines bt-dyndbg enables (opcode, evt, len/mtu).
# Headsets are named from bluetoothd's device list (bluetoothctl devices);
# addresses are never printed. Read-only.
#
# Columns: setup time | headset | air (msbc/cvsd/?) | alt-1 27-byte buffers |
# streamed s (air-mode notify to the next command) | outcome:
#   hangup-ok <ms>     0x0406 Disconnect answered, latency: the kernel's
#                      "opcode 0x0406 status" line, which hci_event_packet()
#                      prints with status 0 for ANY Disconnection Complete while
#                      a Disconnect is pending (no handle, not the event's own
#                      status); a failed Command Status prints its status. It
#                      shows the controller answered, not which link closed: for
#                      that, scripts/sco-link-closure.py on the capture.
#   DISC-FAILED <st>   the Disconnect's Command Status carried an error
#   TIMEOUT <opcode>   the first command after the stream timed out
#   open               no command yet (link still up, or log ends)
#
# Exit 2, with a line on stderr and NO table, when the boot's kernel journal
# cannot be read (an unknown boot, rotated away, no permission): "links 0
# hang-ups answered 0 timeouts 0" would otherwise be printed for it and read as
# a measured zero. A boot that reads fine but holds no SCO line IS a measured
# zero: the table header and "links 0 ..." are printed and the exit status is 0.
set -uo pipefail
BOOT="${1:-0}"
STORE="${BT_BLUEZ_STORE:-/var/lib/bluetooth}"   # a seam, so a test never reads the real store
# Readable at all? One line, any line: a boot with no kernel journal prints
# nothing or fails, and neither is a count of zero.
if ! PROBE=$(journalctl -k -b "$BOOT" --no-pager -q -n 1 -o cat 2>&1) || [[ -z "$PROBE" ]]; then
	echo "sco-ledger: the kernel journal of boot $BOOT cannot be read (${PROBE:-no output}) — no counts, not a zero" >&2
	exit 2
fi
# Names: bluetoothd's persistent store first (every device the adapter has known,
# including ones not currently listed), then its live list. Root reads the store.
NAMES=$( {
	for f in "$STORE"/*/cache/* "$STORE"/*/*/info; do
		[[ -r "$f" ]] || continue
		mac=$(basename "$f"); [[ "$mac" == info ]] && mac=$(basename "$(dirname "$f")")
		n=$(grep -m1 '^Name=' "$f" 2>/dev/null) && printf '%s\t%s\n' "${mac^^}" "${n#Name=}"
	done
	bluetoothctl devices 2>/dev/null | awk '{ m = toupper($2); $1 = $2 = ""; sub(/^ +/, ""); print m "\t" $0 }'
} )

# journalctl --grep exits 1 when NOTHING matched, which under pipefail made a
# readable boot with no SCO call look like a failure. The probe above already
# proved the boot is readable, so: exit 0 is lines, exit 1 with an empty
# standard error is "no match" (a measured zero), anything else is an error.
ERRF=$(mktemp) || exit 1
trap 'rm -f "$ERRF"' EXIT
RAW=$(journalctl -k -b "$BOOT" --no-pager -q -o short-iso-precise \
	--grep 'hci0: dst [0-9a-f:]+ handle|opcode 0x0428|opcode 0x043d|hci0 evt [45]$|len [0-9]+ mtu 9|reason 0x13|opcode 0x0406 status|command( 0x[0-9a-f]+)? tx timeout' 2>"$ERRF"); jrc=$?
if (( jrc > 1 )) || { (( jrc == 1 )) && [[ -s "$ERRF" ]]; }; then
	echo "sco-ledger: reading the kernel journal of boot $BOOT failed (exit $jrc: $(head -c 200 "$ERRF" | tr '\n' ' ')) — no counts, not a zero" >&2
	exit 2
fi
awk -v names="$NAMES" '
# seconds since the start of the month: enough for a boot, and correct across midnight
function secs(ts,   t) { t = substr(ts, 12, 15); split(t, h, ":"); return substr(ts, 9, 2) * 86400 + h[1] * 3600 + h[2] * 60 + h[3] }
function name(mac) { return (mac in N) ? N[mac] : "(unknown device)" }
function close_link(outcome) {
	if (!open) return
	# an open link has no command yet: it has streamed until the last line read
	tend = (outcome == "open") ? tlast : tcmd
	printf "%-26s  %-18s  %-5s  %8d  %9.2f  %s\n", t0, name(peer), air, n27, (tup ? tend - tup : 0), outcome
	links++; if (outcome ~ /^hangup-ok/) ok++; if (outcome ~ /^TIMEOUT/) to++
	open = 0
}
BEGIN {
	n = split(names, L, "\n"); for (i = 1; i <= n; i++) { split(L[i], f, "\t"); N[f[1]] = f[2] }
	printf "%-26s  %-18s  %-5s  %8s  %9s  %s\n", "setup", "headset", "air", "len27/9", "streamed", "outcome"
}
{ tlast = secs($1) }
/hci0: dst [0-9a-f:]+ handle/ { for (i = 1; i <= NF; i++) if ($i == "dst") lastdst = toupper($(i + 1)); next }
/opcode 0x0428|opcode 0x043d/ {
	close_link("open")
	open = 1; t0 = substr($1, 1, 26); peer = lastdst; air = "?"; n27 = 0; tup = 0; tcmd = 0; pending = 0
	next
}
/hci0 evt 5$/ { if (open) { air = "msbc"; tup = secs($1) } next }
/hci0 evt 4$/ { if (open) { air = "cvsd"; tup = secs($1) } next }
/len 27 mtu 9/ { if (open) n27++; next }
/reason 0x13/ { if (open) { tcmd = secs($1); pending = 1 } next }
/opcode 0x0406 status/ {
	# a nonzero status is a failed Command Status of the Disconnect, not an answer
	if (open && pending) {
		if ($NF == "0x00") close_link(sprintf("hangup-ok %d ms", (secs($1) - tcmd) * 1000))
		else close_link("DISC-FAILED " $NF)
	}
	next
}
/command( 0x[0-9a-f]+)? tx timeout/ {
	# the command form only: `link tx timeout` is ACL supervision, not BT-1
	if (open) { if (!tcmd) tcmd = secs($1) - 2.0; op = $0; sub(/.*command /, "", op); sub(/ tx timeout.*/, "", op); close_link("TIMEOUT " op) }
	next
}
END {
	close_link("open")
	printf "\nlinks %d   hang-ups answered %d   timeouts %d\n", links, ok, to
}' <<<"$RAW"

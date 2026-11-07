#!/bin/bash
# test-journal-fast.sh — the fast kernel path of tools/lib/journal.sh must print exactly
# what plain journalctl prints, with the same exit status. Runs both on the REAL journal
# (read-only) for each query, compares byte for byte, and times both.
#
#   devtools/test-journal-fast.sh [<boot -1 day, e.g. 2026-10-22>]
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tools/lib/journal.sh
source "$ROOT/tools/lib/journal.sh"
D=${1:-2026-10-22}
W="$ROOT/tmp/test-journal-fast"; mkdir -p "$W"
B1=$(journalctl --list-boots --no-pager | awk '$1 == "-1" { print $2 }')
B0START=$(journalctl --list-boots --no-pager | awk '$1 == "0" { print $4" "$5 }')
B1END=$(journalctl --list-boots --no-pager | awk '$1 == "-1" { print $(NF-2)" "$(NF-1) }')
EPOCH0=$(date -d "$B0START" +%s)
pass=0 fail=0
run() { # <name> <args...>
	local name="$1"; shift
	local t0 t1 t2 rcs rcf
	t0=$(date +%s.%N)
	BT_JOURNAL_FAST=0 bt_journal "$@" > "$W/slow.out" 2>/dev/null; rcs=$?
	t1=$(date +%s.%N)
	BT_JOURNAL_FAST=1 bt_journal "$@" > "$W/fast.out" 2>/dev/null; rcf=$?
	t2=$(date +%s.%N)
	if [[ $rcs -eq $rcf ]] && cmp -s "$W/slow.out" "$W/fast.out"; then
		pass=$((pass + 1)); printf 'PASS %-34s lines=%-8s rc=%s  plain %6.1fs  fast %5.1fs\n' \
			"$name" "$(wc -l < "$W/fast.out")" "$rcf" "$(echo "$t1 - $t0" | bc)" "$(echo "$t2 - $t1" | bc)"
	else
		fail=$((fail + 1)); printf 'FAIL %-34s rc plain=%s fast=%s, lines plain=%s fast=%s\n' \
			"$name" "$rcs" "$rcf" "$(wc -l < "$W/slow.out")" "$(wc -l < "$W/fast.out")"
		diff "$W/slow.out" "$W/fast.out" | head -n 6 | sed 's/^/     /'
	fi
}
run "this boot, whole, iso" -k -b 0 --no-pager -o short-iso-precise
run "no -b means this boot" -k --since "@$EPOCH0" --no-pager -o short-iso-precise
run "boot -1, 1 h window, iso" -k -b -1 --since "$D 09:00" --until "$D 10:00" --no-pager -o short-iso-precise
run "boot -1, 3 h, cat, --grep" -k -b -1 --since "$D 09:00" --until "$D 12:00" --no-pager -o cat --grep='hci0: (Opcode|result)'
run "boot -1 by id, 1 h, -p err" -k -b "$B1" --since "$D 12:00" --until "$D 13:00" --no-pager -p err -o short-iso-precise
run "boot -1, its last 40 min" -k -b -1 --since "$(date -d "$B1END 40 min ago" '+%F %T')" --no-pager -o short-iso-precise
run "--grep, no match, no -q" -k -b 0 --no-pager --grep='zzz-no-such-line-zzz'
run "--grep, no match, -q" -k -b 0 -q --no-pager --grep='zzz-no-such-line-zzz'
run "-b0 glued, short output" -k -b0 --no-pager --since "@$EPOCH0" -o short
run "not kernel: falls back" -u bluetooth -b 0 --no-pager -n 5
echo "passed $pass, failed $fail"
rm -f "$W/slow.out" "$W/fast.out"
(( fail == 0 ))

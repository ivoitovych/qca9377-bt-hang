#!/bin/bash
# journal-scan-time.sh — how long a journalctl query takes, and how many lines it
# returns. For sizing the trial closer's reads on a dynamic-debug boot: on the
# first E1 boot (24 h) a --grep-filtered kernel scan took 180 s — server-side
# filtering removes formatting and writing, never traversal.
#
#   scripts/journal-scan-time.sh <journalctl args…>
set -uo pipefail
t0=$(date +%s.%N)
errf=$(mktemp) || exit 2
n=$( { journalctl --no-pager "$@" 2>"$errf"; echo $? > "$errf.rc"; } | wc -l)
t1=$(date +%s.%N)
jrc=$(cat "$errf.rc" 2>/dev/null || echo 2)
# journalctl --grep exits 1 with nothing on stderr when nothing matched: zero lines, a result.
# Any other failure is not a count of zero.
if (( jrc >= 2 )) || { (( jrc == 1 )) && [[ -s "$errf" ]]; }; then
	echo "journal-scan-time: journalctl failed (exit $jrc: $(head -c 150 "$errf" | tr '\n' ' ')) — no count, NOT a zero" >&2
	rm -f "$errf" "$errf.rc"; exit 2
fi
rm -f "$errf" "$errf.rc"
printf 'lines %s   %.1f s   journalctl %s\n' "$n" "$(echo "$t1 - $t0" | bc)" "$*"

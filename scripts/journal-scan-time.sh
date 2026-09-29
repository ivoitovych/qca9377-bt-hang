#!/bin/bash
# journal-scan-time.sh — how long a journalctl query takes, and how many lines it
# returns. For sizing the trial closer's reads on a dynamic-debug boot: on the
# first E1 boot (24 h) a --grep-filtered kernel scan took 180 s — server-side
# filtering removes formatting and writing, never traversal.
#
#   scripts/journal-scan-time.sh <journalctl args…>
set -uo pipefail
t0=$(date +%s.%N)
n=$(journalctl --no-pager "$@" 2>/dev/null | wc -l)
t1=$(date +%s.%N)
printf 'lines %s   %.1f s   journalctl %s\n' "$n" "$(echo "$t1 - $t0" | bc)" "$*"

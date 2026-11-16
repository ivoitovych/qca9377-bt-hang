#!/bin/bash
# compare-frozen.sh DIR OUT [JOURNALCTL]
#
# Runs a fixed list of read-only queries with JOURNALCTL (default: journalctl) on the journal files in DIR and
# writes one tab-separated line per query to OUT:
#   query, exit status, lines, bytes, sha256 of the output
# DIR must be a directory of independent COPIES of archived journal files (cp, not hard links), made once and
# used for both runs, so that rotation and vacuuming of the live journal cannot change the input. Run the
# script before and after the upgrade with the same DIR and compare the two OUT files with diff; they must be
# identical, and the script exits non-zero if any query failed or printed nothing (a pair of failed or empty
# exports would otherwise hash the same).
#
# Termination: every query ends when journalctl finishes; each is limited to CAP seconds (default 7200), exit
# status 124 meaning the limit was hit. Nothing is written outside OUT and a private temporary file.
set -u
DIR=${1:?usage: compare-frozen.sh DIR OUT [JOURNALCTL]}
OUT=${2:?usage: compare-frozen.sh DIR OUT [JOURNALCTL]}
JC=${3:-journalctl}
CAP=${CAP:-7200}
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
newest_boot=$($JC --directory="$DIR" --no-pager --list-boots 2> /dev/null | tail -n 1 | awk '{ print $2 }')
bad=0
: > "$OUT"
run() {
    local name=$1; shift
    local rc lines bytes sha
    timeout "$CAP" $JC --directory="$DIR" --no-pager "$@" > "$tmp" 2> /dev/null
    rc=$?
    lines=$(wc -l < "$tmp")
    bytes=$(wc -c < "$tmp")
    sha=$(sha256sum < "$tmp" | cut -c1-64)
    printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$rc" "$lines" "$bytes" "$sha" >> "$OUT"
    if [ "$rc" -ne 0 ] || [ "$bytes" -eq 0 ]; then
        echo "INVALID: '$name' exit status $rc, $bytes bytes" >&2
        bad=1
    fi
}
run "-o export" -o export
run "-o export -r" -o export -r
run "--list-boots" --list-boots
run "-b newest boot" --boot="$newest_boot"
run "-k -b newest boot" -k --boot="$newest_boot"
run "-n 100" -n 100
run "-n 100 -r" -n 100 -r
run "-o export -n 100" -o export -n 100
exit $bad

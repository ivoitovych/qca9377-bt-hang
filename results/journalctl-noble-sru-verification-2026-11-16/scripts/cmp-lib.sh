#!/bin/bash
# cmp-lib.sh : sourced. runq FIXTURE QUERYNAME EXPECT DIR ARGS... runs the same journalctl query with stock (s819) and
# patched (p820) against DIR, checks each exit status and (unless EXPECT=empty) that the output is not empty, and
# prints one TSV line per build and one verdict line.
#   TSV: fixture, query, build, exit_status, lines, bytes, sha256
#   verdict: fixture, query, SAME | DIFFERENT | INVALID (a command failed, timed out or printed nothing where output was required)
# Termination: each command is limited to CAP seconds (default 7200; exit status 124 = hit the cap, reported INVALID).
P=/work/pkgx
CAP=${CAP:-7200}
runq() {
    local fx=$1 q=$2 expect=$3 dir=$4; shift 4
    local b rc sha n bytes bad=0
    declare -A SHA RC
    for b in s819 p820; do
        timeout $CAP $P/jc-$b --directory="$dir" --no-pager "$@" > /tmp/cmp.$b 2> /tmp/cmp.$b.err
        rc=$?
        n=$(wc -l < /tmp/cmp.$b); bytes=$(wc -c < /tmp/cmp.$b)
        sha=$(sha256sum < /tmp/cmp.$b | cut -c1-64)
        SHA[$b]=$sha; RC[$b]=$rc
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$fx" "$q" "$b" "$rc" "$n" "$bytes" "$sha"
        [ $rc -ne 0 ] && bad=1
        [ "$expect" != empty ] && [ "$bytes" -eq 0 ] && bad=1
    done
    local v=SAME
    [ "${SHA[s819]}" != "${SHA[p820]}" ] && v=DIFFERENT
    [ $bad -eq 1 ] && v="INVALID ($v)"
    printf 'VERDICT\t%s\t%s\t%s\n' "$fx" "$q" "$v"
}
# newest boot id of a directory, for --boot= (stock's output; never printed)
newest_boot() { $P/jc-s819 --directory="$1" --no-pager --list-boots 2>/dev/null | tail -n 1 | awk '{ print $2 }'; }

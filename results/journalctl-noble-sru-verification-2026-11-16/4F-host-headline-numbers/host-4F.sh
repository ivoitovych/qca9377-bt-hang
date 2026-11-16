#!/bin/bash
# 4F on the HOST (no container): the key queries of the default-install measurement, stock 8.19 against the 8.20 test build,
# unpacked binaries run with LD_LIBRARY_PATH, on frozen synthetic copies, --directory=<copy>.
# host-4F.sh SET... ; prints TSV: set, build, query, rc, wall_s, user_s, sys_s, lines_or_bytes, capped(1 = hit the cap)
# Termination: each query ends by itself or at CAP seconds (7200); the sos commands at their own 300 s limit.
set -u
W=<work dir>
CAP=${CAP:-7200}
TIMEFORMAT='%R %U %S'
declare -A JC
JC[patched]="$W/pkgx/hjc-p820"
JC[stock]="$W/pkgx/hjc-s819"

measure() {      # measure SET BUILD LABEL CAP ARGS...
    local set=$1 who=$2 label=$3 cap=$4; shift 4
    local t
    t=$( { time ( timeout $cap ${JC[$who]} --directory=$W/verify/data/4F/$set "$@" 2>/dev/null; echo $? > /tmp/4f.rc ) | wc -l > /tmp/4f.n ; } 2>&1 )
    set -- $t
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$SETNAME" "$who" "$label" "$(cat /tmp/4f.rc)" "$1" "$2" "$3" "$(cat /tmp/4f.n)" "$([ "$(cat /tmp/4f.rc)" = 124 ] && echo 1 || echo 0)"
}
measure_head() { # measure_head SET BUILD LABEL CAP LIMIT ARGS...  (as sos: stops reading at its size limit)
    local set=$1 who=$2 label=$3 cap=$4 limit=$5; shift 5
    local t
    t=$( { time ( ( timeout $cap ${JC[$who]} --directory=$W/verify/data/4F/$set "$@" 2>/dev/null; echo $? > /tmp/4f.rc ) | head -c $limit | wc -c > /tmp/4f.n ) ; } 2>&1 )
    set -- $t
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$SETNAME" "$who" "$label" "$(cat /tmp/4f.rc)" "$1" "$2" "$3" "$(cat /tmp/4f.n)" "$([ "$(cat /tmp/4f.rc)" = 124 ] && echo 1 || echo 0)"
}

for SETNAME in "$@"; do
    for who in patched stock; do
        measure $SETNAME $who "-b (newest boot)" $CAP --no-pager -b
        measure $SETNAME $who "-k -b all" $CAP --no-pager -k -b all
        measure $SETNAME $who "apport: --quiet -b -a --system" $CAP --quiet -b -a --system
        measure $SETNAME $who "sos: --disk-usage" 300 --disk-usage
        measure $SETNAME $who "sos: --list-boots" 300 --list-boots
        measure_head $SETNAME $who "sos full: --no-pager --reverse (first 100 MB)" 300 104857600 --no-pager --reverse
        measure_head $SETNAME $who "sos this boot: --no-pager --boot --reverse (first 100 MB)" 300 104857600 --no-pager --boot --reverse
        measure_head $SETNAME $who "sos last boot: --no-pager --boot -1 --reverse (first 100 MB)" 300 104857600 --no-pager --boot -1 --reverse
        measure $SETNAME $who "-b all (full read)" $CAP --no-pager -b all
    done
done

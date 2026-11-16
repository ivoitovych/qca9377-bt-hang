#!/bin/bash
# Runs inside the container as the unprivileged user (uid 1000). noble-user-part.sh SETNAME
# Prints TSV lines: set, who, query, run, rc, wall_s, user_s, sys_s, lines_or_bytes, capped(0/1)
set -u
SET=$1
CAP=${CAP:-600}
JCS=/usr/bin/journalctl
JCP=/opt/jc/patched/journalctl
TIMEFORMAT='%R %U %S'
unit=cron.service

# measure LABEL RUN COMMAND... ; the command's standard output is counted (lines), stderr dropped
measure() {
    local who=$1 label=$2 run=$3 cap=$4 jc=$5; shift 5
    local t
    t=$( { time ( timeout $cap "$jc" "$@" 2>/dev/null; echo $? > /tmp/rc ) | wc -l > /tmp/n ; } 2>&1 )
    set -- $t
    local capped=0
    [ "$(cat /tmp/rc)" = 124 ] && capped=1
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$SET" "$who" "$label" "$run" "$(cat /tmp/rc)" "$1" "$2" "$3" "$(cat /tmp/n)" "$capped"
}
# measure_head: the first LIMIT bytes of the output, as sos collects it (stops reading at its size limit)
measure_head() {
    local who=$1 label=$2 run=$3 cap=$4 jc=$5 limit=$6; shift 6
    local t
    t=$( { time ( ( timeout $cap "$jc" "$@" 2>/dev/null; echo $? > /tmp/rc ) | head -c $limit | wc -c > /tmp/n ) ; } 2>&1 )
    set -- $t
    local capped=0
    [ "$(cat /tmp/rc)" = 124 ] && capped=1
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$SET" "$who" "$label" "$run" "$(cat /tmp/rc)" "$1" "$2" "$3" "$(cat /tmp/n)" "$capped"
}

for who in patched stock; do
    if [ $who = patched ]; then jc=$JCP; else jc=$JCS; fi
    # the journalctl queries
    measure $who "list-boots" 1 $CAP $jc --no-pager --list-boots
    measure $who "list-boots" 2 $CAP $jc --no-pager --list-boots
    measure $who "list-boots" 3 $CAP $jc --no-pager --list-boots
    for r in 1 2 3; do measure $who "-u cron.service -n 10" $r $CAP $jc --no-pager -u $unit -n 10; done
    measure $who "-b (newest boot)" 1 $CAP $jc --no-pager -b
    measure $who "-b -1" 1 $CAP $jc --no-pager -b -1
    measure $who "-k -b all" 1 $CAP $jc --no-pager -k -b all
    measure $who "-b all (full read)" 1 $CAP $jc --no-pager -b all
    # apport: the command lines of apport 2.28.3 (hookutils.py): attach_journal_errors() without a crash time, and recent_syslog()
    measure $who "apport JournalErrors: --priority=warning -b --lines=1000" 1 $CAP $jc --priority=warning -b --lines=1000
    measure $who "apport recent_syslog: --quiet -b -a --system" 1 $CAP $jc --quiet -b -a --system
    # sos 4.11.2 (logs and systemd plugins): output limited to 100 MB (journal_size), command timeout 300 s
    measure $who "sos journalctl --disk-usage" 1 300 $jc --disk-usage
    measure $who "sos journalctl --list-boots" 1 300 $jc --list-boots
    measure_head $who "sos full: --no-pager --reverse (first 100 MB)" 1 300 $jc 104857600 --no-pager --reverse
    measure_head $who "sos this boot: --no-pager --boot --reverse (first 100 MB)" 1 300 $jc 104857600 --no-pager --boot --reverse
    measure_head $who "sos last boot: --no-pager --boot -1 --reverse (first 100 MB)" 1 300 $jc 104857600 --no-pager --boot -1 --reverse
done

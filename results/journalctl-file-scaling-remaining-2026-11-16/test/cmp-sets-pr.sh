#!/bin/bash
# cmp-sets-pr.sh REF_JOURNALCTL "OTHER_JOURNALCTL ..." DIR... : 24 query kinds in export format, compared by SHA-256.
# (the 14 of the packaging test, plus matches: AND, OR between fields, OR of boots, in both directions)
set -u
A=$1; others=$2; shift 2
for d in "$@"; do
    boots=$($A --directory="$d" --list-boots --no-pager -q 2>/dev/null | awk '{ print $2 }')
    b1=$(echo "$boots" | sed -n 2p); b2=$(echo "$boots" | sed -n 4p); b3=$(echo "$boots" | sed -n 5p)
    since=$($A --directory="$d" -o short-unix --no-pager 2>/dev/null | awk 'NR == 2000 { print int($1); exit }')
    cur=$($A --directory="$d" --no-pager -o export --lines=+3000 2>/dev/null | grep -a '^__CURSOR=' | tail -n 1 | cut -d= -f2-)
    queries=(
        "-o export" "-o export -r" "-o export -n 500" "-o export -k" "-o export _BOOT_ID=$b1" "-o export -b -3"
        "-o export --since=@$since --until=@$((since + 60))" "-o export -r --since=@$since"
        "-o export --reverse -n 3000" "-o export --lines=+3000"
        "-o export --after-cursor=$cur" "-o export --cursor=$cur" "-o export -r --cursor=$cur" "-o export -r --after-cursor=$cur"
        "-o export SYSLOG_IDENTIFIER=kernel" "-o export -r SYSLOG_IDENTIFIER=kernel"
        "-o export _BOOT_ID=$b1 + _BOOT_ID=$b2" "-o export -r _BOOT_ID=$b1 + _BOOT_ID=$b2"
        "-o export _BOOT_ID=$b1 _TRANSPORT=kernel + _BOOT_ID=$b2 PRIORITY=6 + _BOOT_ID=$b3"
        "-o export PRIORITY=7 + _BOOT_ID=$b2"
        "-o export -r _TRANSPORT=kernel + _BOOT_ID=$b3 PRIORITY=7"
        "-o export _BOOT_ID=$b1 + _BOOT_ID=$b2 --after-cursor=$cur"
        "-o export -r _BOOT_ID=$b1 + _BOOT_ID=$b2 --cursor=$cur"
        "-o export -n 50 _BOOT_ID=$b2 + _BOOT_ID=$b3"
    )
    for q in "${queries[@]}"; do
        # shellcheck disable=SC2086
        $A --directory="$d" --no-pager $q > /tmp/cmp-ref.out 2>/dev/null
        ha=$(sha256sum < /tmp/cmp-ref.out | cut -c1-16)
        n=$(grep -a -c '^__CURSOR=' /tmp/cmp-ref.out)
        for v in $others; do
            # shellcheck disable=SC2086
            hb=$($v --directory="$d" --no-pager $q 2>/dev/null | sha256sum | cut -c1-16)
            verdict=same; [ "$ha" = "$hb" ] || verdict=DIFFERENT
            [ "$n" -gt 0 ] || verdict="$verdict, NO ENTRIES"
            printf '%-14s %-9s %7d entries  %s  [%s]\n' "$(basename "$d")" "$verdict" "$n" "${q:0:70}" "$(basename "$(dirname "$v")")"
        done
    done
done

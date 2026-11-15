#!/bin/bash
# same-output.sh A B DIR... — do two journalctl binaries print the same journal?
# For each directory and each query below, both binaries print in export format (every field,
# the cursor included), and the outputs are compared by SHA-256. Prints one line per pair and
# exits 1 if any pair differs or prints nothing.
set -u
A=$1 B=$2; shift 2
rc=0
for d in "$@"; do
    boot=$("$A" --directory="$d" --list-boots --no-pager -q 2>/dev/null | awk 'NR == 2 { print $2 }')
    since=$("$A" --directory="$d" -o short-unix --no-pager 2>/dev/null | awk 'NR == 2000 { print int($1); exit }')
    queries=(
        "-o export"
        "-o export -r"
        "-o export -n 500"
        "-o export -k"
        "-o export _BOOT_ID=$boot"
        "-o export -b -3"
        "-o export --since=@$since --until=@$((since + 60))"
        "-o export -r --since=@$since"
    )
    for q in "${queries[@]}"; do
        # shellcheck disable=SC2086
        ha=$("$A" --directory="$d" --no-pager $q 2>/dev/null | tee >(grep -c '^__CURSOR=' > "$d.na") | sha256sum | cut -c1-16)
        # shellcheck disable=SC2086
        hb=$("$B" --directory="$d" --no-pager $q 2>/dev/null | sha256sum | cut -c1-16)
        sleep 0.2; n=$(cat "$d.na" 2>/dev/null || echo 0)
        verdict=same; [ "$ha" = "$hb" ] || { verdict=DIFFERENT; rc=1; }
        [ "$n" -gt 0 ] || { verdict="$verdict, NO ENTRIES"; rc=1; }
        printf '%-10s %-9s %6d entries  %s\n' "$(basename "$d")" "$verdict" "$n" "$q"
    done
    rm -f "$d.na"
done
exit $rc

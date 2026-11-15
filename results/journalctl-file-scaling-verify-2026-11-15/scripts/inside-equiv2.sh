#!/bin/bash
# inside-equiv2.sh REF "VARIANTS" DIR... : the reference prints each query once; every variant is compared by SHA-256.
# Queries as in the other maintainer's same-output.sh (export format, so every field and the cursor).
set -u
W=/work
ref=$1; vars=$2; shift 2
for v in a b c d e f g h; do
    [ -f $W/bins/$v/journalctl ] && printf '#!/bin/bash\nLD_LIBRARY_PATH=%s/bins/%s exec %s/bins/%s/journalctl "$@"\n' $W $v $W $v > $W/bins/$v/jc && chmod +x $W/bins/$v/jc
done
A=$W/bins/$ref/jc
for d in "$@"; do
    boot=$($A --directory="$d" --list-boots --no-pager -q 2>/dev/null | awk 'NR == 2 { print $2 }')
    since=$($A --directory="$d" -o short-unix --no-pager 2>/dev/null | awk 'NR == 2000 { print int($1); exit }')
    queries=(
        "-o export"
        "-o export -r"
        "-o export -n 500"
        "-o export -k"
        "-o export _BOOT_ID=$boot"
        "-o export -b -3"
        "-o export --since=@$since --until=@$((since + 60))"
        "-o export -r --since=@$since"
        "-o export --reverse -n 3000"
        "-o export --lines=+3000"
    )
    for q in "${queries[@]}"; do
        # shellcheck disable=SC2086
        ha=$($A --directory="$d" --no-pager $q 2>/dev/null | sha256sum | cut -c1-16)
        n=$($A --directory="$d" --no-pager $q 2>/dev/null | grep -a -c '^__CURSOR=')
        for v in $vars; do
            # shellcheck disable=SC2086
            hb=$($W/bins/$v/jc --directory="$d" --no-pager $q 2>/dev/null | sha256sum | cut -c1-16)
            verdict=same; [ "$ha" = "$hb" ] || verdict=DIFFERENT
            [ "$n" -gt 0 ] || verdict="$verdict, NO ENTRIES"
            printf '%-3s vs %-3s %-22s %-9s %7d entries  %s\n' "$v" "$ref" "$(basename $(dirname $d))/$(basename $d)" "$verdict" "$n" "$q"
        done
    done
done

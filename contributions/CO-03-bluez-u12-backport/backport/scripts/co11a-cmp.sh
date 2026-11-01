#!/bin/sh
# Byte comparison of btmon stdout between builds, where both exited 0:
# archive vs stock (is the rebuild the archive's behaviour?), stock vs
# fix1, fix1 vs both.
O=/root/exp/agent-work/co03/review-20261101/co11a/out
T=/root/exp/agent-work/co03/review-20261101/co11a/results.tsv
for pair in "archive stock" "stock fix1" "fix1 both" "stock both"; do
    set -- $pair
    same=0; diffn=0; skipped=0; dl=""
    for c in priv-open lines; do
        for w in 10 60 80 81 82 100 250 3000 5000 piped; do
            ea=$(awk -F'\t' -v b="$1" -v c="$c" -v w="$w" '$1==b && $2==c && $3==w {print $4}' "$T")
            eb=$(awk -F'\t' -v b="$2" -v c="$c" -v w="$w" '$1==b && $2==c && $3==w {print $4}' "$T")
            if [ "$ea" != 0 ] || [ "$eb" != 0 ]; then skipped=$((skipped+1)); continue; fi
            if cmp -s "$O/$1.$c.$w.stdout" "$O/$2.$c.$w.stdout"; then same=$((same+1)); else diffn=$((diffn+1)); dl="$dl $c@$w"; fi
        done
    done
    echo "$1 vs $2: identical $same, different $diffn [$dl ], not both exit 0: $skipped"
done

#!/bin/bash
# analyse-pr.sh TSV... : host TSVs (env variant what K run lines seconds io) -> medians and exponents per 'what'.
W=$WORKDIR
for f in "$@"; do
    for what in $(awk -F'\t' '$6 > 0 { print $3 }' $f | sort -u); do
        echo "=== $(basename $f) : $what"
        awk -F'\t' -v w=$what '$3 == w && $6 > 0 { k = $4; print $2 "\t" k "\t" $5 "\t" $6 "\t" $7 }' $f > /tmp/analyse-pr.tsv
        python3 -I $W/bin/analyse.py /tmp/analyse-pr.tsv
    done
done

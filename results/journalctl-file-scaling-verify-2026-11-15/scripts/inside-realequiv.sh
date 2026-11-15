#!/bin/bash
# Inside the container, real journal mounted read-only at /rj. Compares variants by SHA-256 of the first LINES
# lines of export output (forward and reverse) for the newest K files. Nothing is printed except hashes.
set -u
W=/work
for v in a b c d e f g; do
    printf '#!/bin/bash\nLD_LIBRARY_PATH=%s/bins/%s exec %s/bins/%s/journalctl "$@"\n' $W $v $W $v > $W/bins/$v/jc; chmod +x $W/bins/$v/jc
done
dir=$(ls -d /rj/*/ | head -1)
mapfile -t files < <(ls -t "$dir"*.journal*)
LINES=${LINES:-600000}
# the newest file is live: fix an end time so that runs seconds apart see the same entries
T=$(( $(date +%s) - 3600 ))
cmp_set() {   # ref "variants" k
    local ref=$1 vars=$2 k=$3 args=() f q
    [ "$k" = all ] && k=${#files[@]}
    for f in "${files[@]:0:$k}"; do args+=("--file=$f"); done
    for q in "" "-r"; do
        ha=$(nice -n 19 ionice -c 3 $W/bins/$ref/jc --no-pager -o export --until=@$T $q "${args[@]}" 2>/dev/null | head -n $LINES | sha256sum | cut -c1-16)
        for v in $vars; do
            hb=$(nice -n 19 ionice -c 3 $W/bins/$v/jc --no-pager -o export --until=@$T $q "${args[@]}" 2>/dev/null | head -n $LINES | sha256sum | cut -c1-16)
            verdict=same; [ "$ha" = "$hb" ] || verdict=DIFFERENT
            printf '%s vs %s  newest %s files  first %d export lines %-3s  %s  (%s)\n' "$v" "$ref" "$k" $LINES "${q:-fwd}" "$verdict" "$ha"
        done
    done
}
cmp_set a "b c d" 25
cmp_set e "f g" 50
cmp_set e "f g" 200
cmp_set e "f g" all

#!/bin/bash
# Inside co46-build:1: how many of the entries do e2, p2 and g2 print on the seqnum-mixed sets, and do they agree?
W=/work; T=$W/pkgtest
exec > >(tee $T/result-pr/seqmix-output.txt) 2>&1
for v in e2 p2 g2; do
    printf '#!/bin/bash\nLD_LIBRARY_PATH=%s/bins/%s exec %s/bins/%s/journalctl "$@"\n' $W $v $W $v > $W/bins/$v/jc; chmod +x $W/bins/$v/jc
done
export LD_LIBRARY_PATH=$W/bins/e2
for spec in "1 300" "2 300" "3 300" "5 300" "6 300" "10 300"; do
    set -- $spec
    d=/tmp/sm-$1; rm -rf $d
    python3 -I $T/make-seqnum-set.py $W/bins/e2/systemd-journal-remote $d $1 $2
    total=$((3 * $1 * $2))
    printf 'files per group %s (%s files, %s entries written):' $1 $((3 * $1)) $total
    for v in e2 p2 g2; do
        f=$($W/bins/$v/jc --directory=$d --no-pager -o export 2>/dev/null | grep -a -c '^__CURSOR=')
        r=$($W/bins/$v/jc --directory=$d --no-pager -o export -r 2>/dev/null | grep -a -c '^__CURSOR=')
        printf '  %s fwd %s rev %s' $v $f $r
    done
    echo
    for v in e2 p2 g2; do
        $W/bins/$v/jc --directory=$d --no-pager -o export 2>/dev/null | sha256sum | cut -c1-12 | sed "s/^/    $v forward sha256 /"
    done
done
echo "--- control: the same data with every file keeping its own random seqnum ID (nothing overwritten)"
rm -rf /tmp/sm-ctl; NOIDS=1 python3 -I $T/make-seqnum-set.py $W/bins/e2/systemd-journal-remote /tmp/sm-ctl 10 300
for v in e2 p2 g2; do
    f=$($W/bins/$v/jc --directory=/tmp/sm-ctl --no-pager -o export 2>/dev/null | grep -a -c '^__CURSOR=')
    h=$($W/bins/$v/jc --directory=/tmp/sm-ctl --no-pager -o export 2>/dev/null | sha256sum | cut -c1-12)
    echo "  $v: $f entries of 9000, sha256 $h"
done

#!/bin/bash
# Inside co46-build:1: g2 and p2 against e2 (main at the PR base), byte-identical output on many kinds of journals.
set -u
W=/work
T=$W/pkgtest
R=$W/pkgtest/result-pr
mkdir -p $R
exec > >(tee $R/correctness-output.txt) 2>&1
for v in e2 p2 g2; do
    printf '#!/bin/bash\nLD_LIBRARY_PATH=%s/bins/%s exec %s/bins/%s/journalctl "$@"\n' $W $v $W $v > $W/bins/$v/jc
    chmod +x $W/bins/$v/jc
done
REMOTE=$W/bins/e2/systemd-journal-remote
export LD_LIBRARY_PATH=$W/bins/e2
rm -rf /tmp/sets; mkdir -p /tmp/sets
python3 -I $T/make-sets.py $REMOTE /tmp/sets
for k in 50 100; do for kind in int1 int3m; do mkdir /tmp/sets/$kind-$k; ln $W/data/inter-sets/$kind/$k/*.journal /tmp/sets/$kind-$k/; done; done
mkdir /tmp/sets/seq-100; ln $W/data/synth/sets/100/*.journal /tmp/sets/seq-100/
unset LD_LIBRARY_PATH
echo "################ A. byte-identical output, e2 (main at the PR base) is the reference; p2 = + PR #44579, g2 = + priority-queue prototype"
for s in plain interleaved twomachines int1-50 int3m-50 int3m-100 seq-100; do
    echo "---- $s ($(ls /tmp/sets/$s | wc -l) files)"
    $T/cmp-sets-pr.sh $W/bins/e2/jc "$W/bins/p2/jc $W/bins/g2/jc" /tmp/sets/$s
done
echo
echo "################ B. one file still being written (-f), e2 p2 g2 as concurrent readers"
python3 -I $T/live-test.py $REMOTE /tmp/livedir $W/bins/e2/jc $W/bins/p2/jc $W/bins/g2/jc
echo
echo "################ C. files added to and removed from the directory while it is read (sd-journal API, inotify)"
for v in e2 p2 g2; do
    mkdir -p /tmp/mid
    LD_LIBRARY_PATH=$W/bins/$v python3 -I $T/midread-test.py $W/bins/$v/libsystemd.so.0 $REMOTE /tmp/mid > $R/midread-$v.txt 2>&1
    echo "$v: $(wc -l < $R/midread-$v.txt) scenario lines"
done
echo "--- e2 against p2 and g2 (diff of the result lines; empty = identical)"
diff $R/midread-e2.txt $R/midread-p2.txt > $R/midread-e2-vs-p2.diff && echo "p2: identical"
diff $R/midread-e2.txt $R/midread-g2.txt > $R/midread-e2-vs-g2.diff && echo "g2: identical"
cat $R/midread-e2-vs-p2.diff $R/midread-e2-vs-g2.diff
echo "--- e2's scenario lines"
cat $R/midread-e2.txt
echo
echo "################ D. a journal in which compare_locations() mixes two orders (same seqnum ID, repeated sequence numbers; 3 machine IDs)"
python3 -I $T/make-seqnum-set.py $REMOTE /tmp/sets/seqnum-mix
$T/cmp-sets-pr.sh $W/bins/e2/jc "$W/bins/p2/jc $W/bins/g2/jc" /tmp/sets/seqnum-mix

#!/bin/bash
# Second correctness pass (the first lost its fully interleaved sets to a cross-filesystem hard link and its
# live test to an unset LD_LIBRARY_PATH). Inside co46-build:1.
set -u
W=/work
T=$W/pkgtest
R=$W/pkgtest/result-pr
mkdir -p $R
exec > >(tee $R/correctness-output-2.txt) 2>&1
for v in e2 p2 g2; do
    printf '#!/bin/bash\nLD_LIBRARY_PATH=%s/bins/%s exec %s/bins/%s/journalctl "$@"\n' $W $v $W $v > $W/bins/$v/jc
    chmod +x $W/bins/$v/jc
done
REMOTE=$W/bins/e2/systemd-journal-remote
export LD_LIBRARY_PATH=$W/bins/e2
rm -rf /tmp/sets; mkdir -p /tmp/sets
for k in 50 100; do for kind in int1 int3m; do mkdir /tmp/sets/$kind-$k; cp $W/data/inter-sets/$kind/$k/*.journal /tmp/sets/$kind-$k/; done; done
mkdir /tmp/sets/seq-100; cp $W/data/synth/sets/100/*.journal /tmp/sets/seq-100/
python3 -I $T/make-seqnum-set.py $REMOTE /tmp/sets/seqnum-mix
echo "################ A. byte-identical output, e2 (main at the PR base) is the reference; p2 = + PR #44579, g2 = + priority-queue prototype"
for s in int1-50 int3m-50 int3m-100 seq-100 seqnum-mix; do
    echo "---- $s ($(ls /tmp/sets/$s | wc -l) files)"
    $T/cmp-sets-pr.sh $W/bins/e2/jc "$W/bins/p2/jc $W/bins/g2/jc" /tmp/sets/$s
done
echo
echo "################ B. one file still being written (-f), e2 p2 g2 as concurrent readers (21 files: 20 archived and one live)"
python3 -I $T/live-test.py $REMOTE /tmp/livedir $W/bins/e2/jc $W/bins/p2/jc $W/bins/g2/jc
echo
echo "################ C. files added and removed while the directory is read (sd-journal API, inotify): monotonic time rising across the files of a boot"
rm -rf /tmp/midr; mkdir -p /tmp/midr
for v in e2 p2 g2; do
    # the first variant makes the static and extra files, the others reuse them (the same input for all three)
    LD_LIBRARY_PATH=$W/bins/$v python3 -I $T/midread-test.py $W/bins/$v/libsystemd.so.0 $REMOTE /tmp/midr rising > $R/midread-rising-$v.txt 2>&1
    echo "$v: $(wc -l < $R/midread-rising-$v.txt) scenario lines"
done
diff $R/midread-rising-e2.txt $R/midread-rising-p2.txt > $R/midread-rising-e2-vs-p2.diff && echo "rising: p2 identical to e2"
diff $R/midread-rising-e2.txt $R/midread-rising-g2.txt > $R/midread-rising-e2-vs-g2.diff && echo "rising: g2 identical to e2"
cat $R/midread-rising-e2-vs-p2.diff $R/midread-rising-e2-vs-g2.diff

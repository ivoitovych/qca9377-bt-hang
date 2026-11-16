#!/bin/bash
# Part 1 correctness, inside co46-build:1: e2 is the reference, pg2a and pg2b the builds under test.
set -u
W=/work
T=$W/pkgtest
R=$W/pkgtest/result-pg
mkdir -p $R
exec > >(tee $R/pg-correctness-output.txt) 2>&1
for v in e2 pg2a pg2b; do
    printf '#!/bin/bash\nLD_LIBRARY_PATH=%s/bins/%s exec %s/bins/%s/journalctl "$@"\n' $W $v $W $v > $W/bins/$v/jc
    chmod +x $W/bins/$v/jc
done
REMOTE=$W/bins/e2/systemd-journal-remote
export LD_LIBRARY_PATH=$W/bins/e2
rm -rf /tmp/sets; mkdir -p /tmp/sets
python3 -I $T/make-sets.py $REMOTE /tmp/sets
for k in 50 100; do for kind in int1 int3m; do mkdir /tmp/sets/$kind-$k; cp $W/data/inter-sets/$kind/$k/*.journal /tmp/sets/$kind-$k/; done; done
mkdir /tmp/sets/seq-100; cp $W/data/synth/sets/100/*.journal /tmp/sets/seq-100/
rm -rf /tmp/sets/interleaved-unused
echo "################ A. byte-identical output against e2 (main at the PR base): 24 query kinds per set"
for s in plain interleaved twomachines int1-50 int3m-50 int3m-100 seq-100; do
    echo "---- $s ($(ls /tmp/sets/$s | wc -l) files)"
    $T/cmp-sets-pr.sh $W/bins/e2/jc "$W/bins/pg2a/jc $W/bins/pg2b/jc" /tmp/sets/$s
done
echo
echo "################ B. one file still being written (-f) and a file added while following"
rm -rf /tmp/livedir /tmp/livedir.out*
python3 -I $T/live-test.py $REMOTE /tmp/livedir $W/bins/e2/jc $W/bins/pg2a/jc $W/bins/pg2b/jc
echo
echo "################ C. files added and removed while the directory is read (API, inotify), monotonic time rising"
rm -rf /tmp/midr; mkdir -p /tmp/midr
for v in e2 pg2a pg2b; do
    LD_LIBRARY_PATH=$W/bins/$v python3 -I $T/midread-test.py $W/bins/$v/libsystemd.so.0 $REMOTE /tmp/midr rising > $R/midread-rising-$v.txt 2>&1
    echo "$v: $(wc -l < $R/midread-rising-$v.txt) scenario lines"
done
diff $R/midread-rising-e2.txt $R/midread-rising-pg2a.txt > $R/midread-rising-e2-vs-pg2a.diff && echo "rising: pg2a identical to e2"
diff $R/midread-rising-e2.txt $R/midread-rising-pg2b.txt > $R/midread-rising-e2-vs-pg2b.diff && echo "rising: pg2b identical to e2"
cat $R/midread-rising-e2-vs-pg2a.diff $R/midread-rising-e2-vs-pg2b.diff

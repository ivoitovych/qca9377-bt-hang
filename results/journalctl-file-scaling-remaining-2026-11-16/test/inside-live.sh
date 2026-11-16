#!/bin/bash
# Inside co46-build:1: the follow test again, now with a file added to the directory while the followers run.
W=/work; T=$W/pkgtest
exec > >(tee $T/result-pr/live-output.txt) 2>&1
for v in e2 p2 g2; do
    printf '#!/bin/bash\nLD_LIBRARY_PATH=%s/bins/%s exec %s/bins/%s/journalctl "$@"\n' $W $v $W $v > $W/bins/$v/jc; chmod +x $W/bins/$v/jc
done
export LD_LIBRARY_PATH=$W/bins/e2
rm -rf /tmp/livedir /tmp/livedir.out*
python3 -I $T/live-test.py $W/bins/e2/systemd-journal-remote /tmp/livedir $W/bins/e2/jc $W/bins/p2/jc $W/bins/g2/jc

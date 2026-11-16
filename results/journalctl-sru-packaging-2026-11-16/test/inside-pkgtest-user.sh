#!/bin/bash
# Runs INSIDE the test container as the unprivileged user "tester".
set -u
T=/work/pkgtest
R=$T/result
cd /tmp
export TMPDIR=/tmp
REMOTE=/usr/lib/systemd/systemd-journal-remote
snap() {
    for d in /var/log /run/log /etc/systemd; do [ -e "$d" ] && find "$d" -xdev -printf '%p %y %s %T@\n' 2>/dev/null; done
}
snap > /tmp/.snap-before

echo "################ A. the reproducer, as $(id -un), against the installed (patched) /usr/bin/journalctl"
KEEP=1 /repro/journalctl-file-scaling-repro.sh /usr/bin/journalctl 25 50 100 200 400 > /tmp/repro.out 2>&1
cat /tmp/repro.out
dir=$(sed -n 's/^KEEP is set: the files stay in \([^ ]*\) .*/\1/p' /tmp/repro.out)
echo "files kept in $dir: $(ls $dir/all | wc -l)"

echo
echo "################ B. journalctl --verify on the reproducer's files (patched binary)"
fail=0; n=0
for f in $dir/all/*.journal; do
    n=$((n + 1))
    /usr/bin/journalctl --verify --file="$f" > /tmp/verify.out 2>&1 || { fail=$((fail + 1)); [ $fail -le 3 ] && { echo "FAIL $f"; tail -3 /tmp/verify.out; }; }
done
echo "verified $n files, $fail failed"
echo "--directory form on 10 files:"
mkdir /tmp/ten; for f in $(ls $dir/all/*.journal | head -10); do ln $f /tmp/ten/; done
/usr/bin/journalctl --verify --directory=/tmp/ten 2>&1 | tail -n 3; echo "exit status ${PIPESTATUS[0]}"
echo "same files, the stock 8.18 binary:"
/opt/jc/stock-8.18/journalctl --verify --directory=/tmp/ten 2>&1 | tail -n 3; echo "exit status ${PIPESTATUS[0]}"
rm -rf /tmp/ten

echo
echo "################ C. equivalence sets (written with the installed systemd-journal-remote)"
rm -rf /tmp/sets
python3 -I $T/make-sets.py $REMOTE /tmp/sets
echo "sets: $(ls /tmp/sets)"
echo "-- also the reproducer's own files, 25 of them"
for k in 25; do mkdir /tmp/sets/repro$k; for f in $(ls $dir/all/*.journal | head -n $k); do ln $f /tmp/sets/repro$k/; done; done
W="/opt/jc/stock-8.19/journalctl /opt/jc/patched/journalctl"
for s in plain interleaved twomachines repro25; do
    echo "---- $s: 8.18 stock is the reference; 8.19 stock and the patched build against it"
    $T/cmp-sets.sh /opt/jc/stock-8.18/journalctl "$W" /tmp/sets/$s
done

echo
echo "################ D. one file still being written"
python3 -I $T/live-test.py $REMOTE /tmp/livedir /opt/jc/stock-8.18/journalctl /opt/jc/stock-8.19/journalctl /opt/jc/patched/journalctl

echo
echo "################ E. safety: /var/log, /run/log, /etc/systemd before and after the unprivileged part"
snap > /tmp/.snap-after
if diff /tmp/.snap-before /tmp/.snap-after > /tmp/.snap-diff; then echo "identical ($(wc -l < /tmp/.snap-before) entries)"; else echo DIFFERENT; cat /tmp/.snap-diff; fi
rm -rf "$dir" /tmp/sets /tmp/livedir /tmp/livedir.out*

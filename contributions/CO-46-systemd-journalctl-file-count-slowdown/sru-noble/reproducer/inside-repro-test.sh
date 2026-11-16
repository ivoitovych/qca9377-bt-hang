#!/bin/bash
# Runs INSIDE the test container as the unprivileged user "tester".
#   inside-repro-test.sh BINARY...   : the script is run once per binary, with a snapshot of the places that
#   must not change taken before and after.
snap() {
    # path, type, size, mtime of everything below these directories, and of the directories themselves
    for d in /var/log /run/log /etc/systemd; do
        [ -e "$d" ] && find "$d" -xdev -printf '%p %y %s %T@\n' 2>/dev/null
    done
    # /tmp and /var/tmp: the scratch directory the script makes (and removes) lives directly in /tmp, which
    # changes /tmp's own mtime; so list what is inside, not the directories' own mtimes
    for d in /tmp /var/tmp; do
        [ -e "$d" ] && find "$d" -xdev -mindepth 1 -printf '%p %y %s %T@\n' 2>/dev/null
    done
}
id
echo "journal directories present before: $(ls -d /var/log/journal /run/log/journal 2>&1 | tr '\n' ' ')"
snap > /tmp/.snap-before
for jc in "$@"; do
    echo
    echo "################ $jc"
    /repro/journalctl-file-scaling-repro.sh "$jc"
done
snap > /tmp/.snap-after
echo
echo "################ safety check: /var/log, /run/log, /etc/systemd, /tmp, /var/tmp before and after"
if diff <(grep -v '^/tmp/.snap' /tmp/.snap-before) <(grep -v '^/tmp/.snap' /tmp/.snap-after) > /tmp/.snap-diff; then
    echo "identical: $(grep -vc '^/tmp/.snap' /tmp/.snap-before) entries (path type size mtime), no difference"
else
    echo "DIFFERENT:"; cat /tmp/.snap-diff
fi
echo "journal directories present after: $(ls -d /var/log/journal /run/log/journal 2>&1 | tr '\n' ' ')"
echo "leftover scaling directories in /tmp: $(ls -d /tmp/journalctl-scaling.* 2>/dev/null | wc -l)"

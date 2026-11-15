#!/bin/bash
# Inside the container: systemd's own journal tests on the prototype tree (v-g, or the tree named by $1).
set -u
cd /work/src/v-${1:-g} || exit 1
nice -n 19 meson setup build-t --buildtype=debugoptimized -Dmode=developer -Dtests=true -Dman=disabled -Dhtml=disabled -Dtranslations=false > /work/tests-setup.log 2>&1 || { tail -20 /work/tests-setup.log; exit 1; }
T="test-journal test-journal-interleaving test-journal-enum test-journal-flush test-journal-init test-journal-match test-journal-stream test-journal-verify test-journal-file test-mmap-cache"
nice -n 19 ninja -C build-t -j6 $T > /work/tests-build.log 2>&1 || { tail -30 /work/tests-build.log; exit 1; }
for t in $T; do
    if [ -x build-t/$t ]; then
        timeout 300 build-t/$t > /work/tests-$t.log 2>&1
        echo "$t exit $?"
    else
        echo "$t not built"
    fi
done

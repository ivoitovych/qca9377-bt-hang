#!/bin/bash
# Inside the container: the journal tests again with the queue built for any number of files (-DHEAP_MIN_FILES=2),
# so that the small journals of systemd's own tests exercise it.
set -u
cd /work/src/v-g || exit 1
rm -rf build-t2
nice -n 19 meson setup build-t2 --buildtype=debugoptimized -Dmode=developer -Dtests=true -Dman=disabled -Dhtml=disabled -Dtranslations=false -Dc_args=-DHEAP_MIN_FILES=2 > /work/tests2-setup.log 2>&1 || { tail -20 /work/tests2-setup.log; exit 1; }
T="test-journal test-journal-interleaving test-journal-enum test-journal-flush test-journal-init test-journal-match test-journal-stream test-journal-verify test-journal-file test-mmap-cache"
nice -n 19 ninja -C build-t2 -j6 $T > /work/tests2-build.log 2>&1 || { tail -30 /work/tests2-build.log; exit 1; }
for t in $T; do
    timeout 300 build-t2/$t > /work/tests2-$t.log 2>&1
    echo "$t exit $?"
done

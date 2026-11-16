#!/bin/bash
# Inside co46-build:1: systemd's journal unit tests on a variant tree. inside-tests-pr.sh VARIANT [EXTRA_C_ARGS]
v=$1; ca=${2:-}
cd /work/src/v-$v || exit 1
b=build-t${ca:+-forced}
rm -rf $b
nice -n 19 ionice -c 3 meson setup $b --buildtype=debugoptimized -Dmode=developer -Dtests=true -Dman=disabled -Dhtml=disabled -Dtranslations=false ${ca:+-Dc_args=$ca} > /work/tests-$v$ca.setup.log 2>&1 || { tail -20 /work/tests-$v$ca.setup.log; exit 1; }
T="test-journal test-journal-interleaving test-journal-enum test-journal-flush test-journal-init test-journal-match test-journal-stream test-journal-verify test-journal-file test-mmap-cache test-journal-send"
nice -n 19 ionice -c 3 ninja -C $b -j6 $T > /work/tests-$v$ca.build.log 2>&1 || { tail -30 /work/tests-$v$ca.build.log; exit 1; }
echo "== $v ${ca:-(as built)}"
for t in $T; do
    if [ -x $b/$t ]; then
        timeout 600 $b/$t > /work/tests-$v-$t.log 2>&1
        echo "$t exit $?"
    else
        echo "$t not built"
    fi
done

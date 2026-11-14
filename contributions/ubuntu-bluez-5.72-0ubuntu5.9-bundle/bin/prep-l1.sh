#!/bin/bash
# make the generated header symlinks (BUILT_SOURCES) in the two configured fresh trees, then run the L1 harness
B=/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle
for v in base bundle; do
  docker run --rm -v "$B/fresh/$v/bluez-5.72:/b" -w /b co03-noble-build:1 sh -c '
    H=$(make -s --eval="pr: ; @echo \$(local_headers)" pr)
    make -j4 $H src/builtin.h >/dev/null 2>&1; echo "headers rc=$?"; ls lib/bluetooth/bluetooth.h'
done

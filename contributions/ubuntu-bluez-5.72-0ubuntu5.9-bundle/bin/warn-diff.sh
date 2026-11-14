#!/bin/bash
# compiler warnings of the package builds and of the ASan builds, base vs bundle (line numbers removed)
B=/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle
L=$B/logs
norm() { grep -a 'warning:' "$1" | sed -e 's/:[0-9]*:[0-9]*:/:/' -e 's#/build/bluez-5.72/##' | sort; }
{
for k in pkg-build asan-build; do
  case $k in
    pkg-build) a=$L/pkg-build-base.log; b=$L/pkg-build-bundle.log ;;
    asan-build) a=$L/asan-build-base.log; b=$L/asan-build-bundle.log ;;
  esac
  echo "== $k: warnings base $(grep -a -c 'warning:' "$a"), bundle $(grep -a -c 'warning:' "$b")"
  diff <(norm "$a") <(norm "$b") && echo "   identical warning sets"
done
} > "$L/warnings-diff.txt" 2>&1
cat "$L/warnings-diff.txt"

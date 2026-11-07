#!/bin/sh
# SHA256SUMS of everything this experiment produced (runs, scripts, tests,
# logs) plus the source files and the binaries used.
top=/root/exp/agent-work/u29-t2-temporary-lifetime
cd "$top" || exit 1
{
    find runs scripts tests logs -type f ! -name '*.pyc' | sort | xargs sha256sum
    sha256sum src/bluez-5.72/src/adapter.c src/bluez-5.72/src/device.c PROGRESS.log
} > SHA256SUMS
echo "$(grep -c '' SHA256SUMS) lines"

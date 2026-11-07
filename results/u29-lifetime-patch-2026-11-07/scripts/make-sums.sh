#!/bin/sh
# SHA256SUMS of patches, scripts, tests, logs and every raw run file.
top=/root/exp/agent-work/u29-t3-lifetime-patch
cd "$top" || exit 1
find patch scripts tests logs runs PROGRESS.log -type f ! -name '*.pyc' | sort | xargs sha256sum > SHA256SUMS
grep -c "" SHA256SUMS

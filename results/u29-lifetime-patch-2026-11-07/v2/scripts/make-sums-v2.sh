#!/bin/sh
# SHA256SUMS of everything round 2 produced: patch-v2, scripts-v2, tests_v2,
# logs-v2, runs-v2 (the old runs/ and logs/ keep their own SHA256SUMS).
# Written to logs-v2/SHA256SUMS.
top=/root/exp/agent-work/u29-t3-lifetime-patch
cd "$top" || exit 1
find patch-v2 scripts-v2 tests_v2 logs-v2 runs-v2 -type f ! -name '*.pyc' ! -name SHA256SUMS | sort | xargs sha256sum > logs-v2/SHA256SUMS
grep -c "" logs-v2/SHA256SUMS

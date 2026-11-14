#!/bin/bash
T=/root/exp/agent-work/lane5-status-stable-20261114/task5
du -sh "$T"/* > "$T/logs/sizes-before-cleanup.txt"
mkdir -p "$T/logs/builds"
for p in wp gcc; do for f in "$T/$p"/build-*.log "$T/$p"/dpkg-source-b.log "$T/$p"/build-dep.log; do cp "$f" "$T/logs/builds/$p-$(basename "$f")"; done; done
rm -rf "$T/wp" "$T/gcc" "$T/mk"
cd "$T" && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
wc -l SHA256SUMS; du -sh "$T"

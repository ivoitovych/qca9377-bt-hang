#!/bin/bash
# remove my build trees, keep logs, results, debdiffs, fetched pages; write SHA256SUMS
T=/root/exp/agent-work/lane5-status-stable-20261114/task4
du -sh "$T"/* > "$T/logs/sizes-before-cleanup.txt"
rm -rf "$T/trees" "$T/live/build" "$T/work/build/resolute/stock" "$T/work/build/resolute/patched" "$T/work/build/resolute/new" \
       "$T/work/build/stonking/stock" "$T/work/build/stonking/patched" "$T/work/build/stonking/new" "$T/work/build/tenacious/src" "$T/live-vm/archive-deb"
cd "$T" && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
wc -l SHA256SUMS
du -sh "$T"

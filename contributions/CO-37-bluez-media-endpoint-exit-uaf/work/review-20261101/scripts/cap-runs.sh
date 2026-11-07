#!/bin/bash
# cap-runs.sh <tree> <label> <first run number to skip>
# Stop a running batch early without killing it: asan-tree.sh refuses to
# overwrite an existing <label>-<i>.log and exits, so a placeholder log
# for run <i> ends that loop there. Used on 2026-11-01 when the root
# filesystem ran out of space for non-root users (each failing run left
# ~100-140 MB ASan core dumps per crash).
set -eu
W=/root/exp/agent-work/co23-co37-review-20261101
f=$W/runs/$1/$2-$3.log
[[ -e "$f" ]] && { echo "exists: $f"; exit 0; }
echo "placeholder $(date '+%H:%M:%S'): run capped here to save disk space (scripts/cap-runs.sh); not a test result" > "$f"
echo "capped: $f"

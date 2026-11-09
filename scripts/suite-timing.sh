#!/bin/bash
# suite-timing.sh <checkout> <outdir> — each run alone on the machine, and its wall time.
#
# The question (2026-11-08): why a merge cycle takes about 25 minutes, and what can be made
# faster without losing any check. A run that shares the cores with another measures the
# contention, not itself, so these run one after another, nothing else running. Each run's
# output is kept beside the summary. Results of the first run: results/suite-timing-2026-11-08/.
set -u
WT=${1:?usage: suite-timing.sh <checkout> <outdir>}; O=${2:?usage: suite-timing.sh <checkout> <outdir>}
mkdir -p "$O" && O=$(cd "$O" && pwd) && cd "$WT" || exit 2
step() { local n=$1; shift; local t0=$EPOCHREALTIME
  "$@" > "$O/$n.log" 2>&1; local rc=$?
  printf '%-10s rc=%d  %7.1f s\n' "$n" "$rc" "$(echo "$EPOCHREALTIME - $t0" | bc)" | tee -a "$O/summary.txt"; }
: > "$O/summary.txt"; echo "cores: $(nproc)" >> "$O/summary.txt"
step plain    tests/run-tests
step serial   tests/run-tests --serial
step cov      devtools/coverage --quiet --min 80
step comp     devtools/test-comprehension --min 75
step awk      devtools/awk-coverage --min 95
step py       devtools/py-coverage --min 80
step jc       devtools/journal-contract
step scan     devtools/repo-scan . --all
step mutself  devtools/mutate --self-test
step sandbox  devtools/sandbox
step audit    devtools/access-audit --report "$O/audit-report"

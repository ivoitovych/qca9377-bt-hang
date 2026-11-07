#!/bin/sh
# Builds the final tables of agent-work/co36 from every results file that
# counts (r03..r03d and r06 are superseded harness tries; they are kept
# but summarized separately):
#   results/summary-all.txt      per record and the T233 ledger
#   results/ranges-all.txt       per test: short links, leaks, ranges
#   results/summary-superseded.txt
#   results/t236-scan-all.txt    sanitizer and crash scan of every log
set -eu
w=/root/exp/agent-work/co36
r=$w/results
python3 -I $w/scripts/summarize.py $r/summary-all.txt \
    $r/r01-smoke-results.jsonl $r/r02-all-once-results.jsonl \
    $r/r04-timing-x5-results.jsonl $r/r05-t224-x10-results.jsonl \
    $r/r06b-t308-x5-results.jsonl $r/r07-t234-try-results.jsonl \
    $r/r07b-t234-try-results.jsonl $r/r08-l3-x5-results.jsonl \
    $r/r09-more-x3-results.jsonl
python3 -I $w/scripts/ranges.py \
    $r/r01-smoke-results.jsonl $r/r02-all-once-results.jsonl \
    $r/r04-timing-x5-results.jsonl $r/r05-t224-x10-results.jsonl \
    $r/r06b-t308-x5-results.jsonl $r/r08-l3-x5-results.jsonl \
    $r/r09-more-x3-results.jsonl > $r/ranges-all.txt
python3 -I $w/scripts/summarize.py $r/summary-superseded.txt \
    $r/r03-t308-try-results.jsonl $r/r03b-t308-try-results.jsonl \
    $r/r03c-t308-try-results.jsonl $r/r03d-t308-try-results.jsonl \
    $r/r06-t308-x5-results.jsonl
python3 -I $w/scripts/scan_sanitizers.py $r/t236-scan-all.txt $r $w/logs
echo done

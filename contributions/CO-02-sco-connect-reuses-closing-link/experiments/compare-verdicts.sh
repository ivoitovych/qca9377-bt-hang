#!/bin/bash
# compare-verdicts.sh - CO-02 hardware prep: per-case verdicts of two tester logs (colour codes
# stripped), and the cases whose verdict differs. Usage: compare-verdicts.sh <log A> <log B>
set -u
A=${1:?usage}; B=${2:?usage}
# The summary table ("<case>  Passed  0.024 seconds") when the run finished; for a run stopped at
# the time limit (no table), the per-case progress lines ("<case> - test passed").
v() {
	local s; s=$(sed -e 's/\x1b\[[0-9;]*m//g' "$1")
	if grep -q -a -E '^Total: ' <<<"$s"; then
		grep -a -E '  +(Passed|Failed|Not Run|Timed out) ' <<<"$s" | sed -E 's/[[:space:]]+[0-9.]+ seconds[[:space:]]*$//; s/ {2,}/\t/; s/[[:space:]]+$//'
	else
		grep -a -E ' - test (passed|failed|timed out)' <<<"$s" | sed -E 's/ - test /\t/; s/[[:space:]]+$//'
	fi | sort
}
echo "A: $(v "$A" | wc -l) verdicts, B: $(v "$B" | wc -l) verdicts"
diff <(v "$A") <(v "$B") && echo "no verdict differs"

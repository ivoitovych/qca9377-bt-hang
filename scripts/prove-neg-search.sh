#!/bin/bash
# The three negative-search assertions that ran through a missing ripgrep and
# passed anyway (deep review 2026-09-20, DP-01): run their grep forms here and
# report the exit code of each — 1 is the negative result the suite wants, 0 is
# a real finding, 2 is a broken search. Read-only.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2   # the checkout this script lives in, wherever it was cloned
show() { local rc=$1; case $rc in 1) echo "rc=1 no match (pass)";; 0) echo "rc=0 MATCH (would fail)";; *) echo "rc=$rc search ERROR (would fail)";; esac; }
FILES=(README.md docs/bug-report.md docs/fix-proposal.md bin/bt-usbmon bin/bt-hang-watchdog tools/bt-status tools/bt-postmortem tools/bt-health-report.sh)
out=$(grep -nE -i 'failure has two stages|controller fails in two stages|recoverable window closes|window closes sharply|exact operation usb_queue_reset_device|autosuspend was the trigger|stage 1 lasted ~6 hours|reached stage 2 before|cheap and safe' "${FILES[@]}" 2>/dev/null); rc=$?
echo "retired assertions:   $(show $rc)"; [[ $rc == 0 ]] && sed 's/^/    /' <<<"$out" | head -5
out=$(grep -nE 'BT-[1-4]' docs/bug-report.md 2>/dev/null); rc=$?
echo "bug-report labels:    $(show $rc)"; [[ $rc == 0 ]] && sed 's/^/    /' <<<"$out" | head -5
out=$(grep -nE 'BT-[1-4]' README.md docs/fix-proposal.md 2>/dev/null); rc=$?
echo "outward labels found: $(show $rc) (0 expected: labels exist, then filtered)"
if (( rc == 0 )); then
    bare=$(grep -vE '\(`?BT-[1-4]`?[),]|`BT-[1-4]`,[[:space:]]+[[:alnum:]]' <<<"$out"); brc=$?
    echo "bare labels after filter: $(show $brc)"; [[ $brc == 0 ]] && sed 's/^/    /' <<<"$bare" | head -8
fi
# The guard itself, the same regex as in tests/run-tests, over the suite's files and
# over a positive control carrying the three invocation shapes the first guard missed.
RGRE='^[^#]*(^|[;&|(]|\$\()[[:space:]]*rg[[:space:]]'
mapfile -t SF < <(printf '%s\n' tests/run-tests tests/parts/*.sh 2>/dev/null | while read -r f; do [[ -f "$f" ]] && echo "$f"; done)
hits=$(grep -HnE "$RGRE" "${SF[@]}" 2>/dev/null | grep -vcE 'RG_HITS=|deep-review follow-up|command token')
echo "ripgrep in suite (${#SF[@]} file(s)): $hits line(s) (0 expected)"
T=$(mktemp); printf 'x=$(rg -n "a" f)\nrg "BT-[1-4]" file\n  rg pattern file | head\n# rg in a comment does not count\nfoo=$(grep -c rg file)\n' > "$T"
det=$(grep -cE "$RGRE" "$T")
echo "guard positive control: $det of 3 rg shapes detected, comment and word 'rg' not counted (3 expected)"; rm -f "$T"

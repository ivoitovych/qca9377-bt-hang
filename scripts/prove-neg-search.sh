#!/bin/bash
# The three negative-search assertions that ran through a missing ripgrep and
# passed anyway (deep review 2026-09-20, DP-01): run their grep forms here and
# report the exit code of each — 1 is the negative result the suite wants, 0 is
# a real finding, 2 is a broken search. Read-only.
set -uo pipefail
cd /root/exp/qca9377-bt-hang || exit 2
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
echo "ripgrep in suite:     $(grep -cE '^[^#]*\brg (-[a-zA-Z]|'"'"')' tests/run-tests) line(s) (0 expected)"

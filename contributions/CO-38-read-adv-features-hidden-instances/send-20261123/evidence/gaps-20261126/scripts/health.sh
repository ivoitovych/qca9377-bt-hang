#!/bin/bash
# health.sh : one status block for the periodic check of the running batch (all-gaps.sh). Reads only.
#  - is the driver alive, which stage, the last progress line and its age;
#  - the guest or build running now, its elapsed time and CPU, and the size and age of the log it writes;
#  - free disk; a verdict line: OK, DONE, STOPPED, STALE (no progress for 20+ min) or DEAD (no driver, not done).
set -u
W3=<work area>/tips3
L=$W3/progress.log
now=$(date +%s)
echo "health $(date -u '+%F %T') UTC"
drv=$(pgrep -f 'kernel-queue-20261126/(all-gaps|build-next2|run-gaps|bot-co38|bot-base-rerun)\.sh' | wc -l)
echo "driver processes: $drv"
last=$(tail -n 1 "$L" 2>/dev/null)
age=$(( now - $(stat -c %Y "$L" 2>/dev/null || echo "$now") ))
echo "last progress ($((age / 60)) min ago): $last"
ps -eo pid,etimes,pcpu,args --sort=-pcpu | grep -E 'qemu-system|make -C|docker run|test-runner -q' | grep -v grep | head -n 4 |
	awk '{printf "  pid %s up %d min cpu %s%% %s\n", $1, $2/60, $3, substr($0, index($0,$4), 110)}'
cur=$(ls -t "$W3"/runs/*.log 2>/dev/null | head -n 1)
[[ -n $cur ]] && echo "newest log: $(basename "$cur") $(stat -c %s "$cur") bytes, written $(( (now - $(stat -c %Y "$cur")) / 60 )) min ago"
echo "free disk: $(df -h --output=avail / | tail -n 1 | tr -d ' ')"
# The bot stage writes progress lines only at its start and end: judge it by its own output instead.
BOTD=/root/exp/qca9377-bt-hang/tmp/kernel-queue-20261126
if [[ $last == *"bot kernel start"* || $last == *"bot bluez start"* || $last == *"bot base rerun start"* ]]; then
	newest=$(find "$BOTD"/bot-co38-k "$BOTD"/bot-co38-bluez "$BOTD"/bot-co38-k-base "$BOTD"/bot-co38-k.log "$BOTD"/bot-co38-bluez.log "$BOTD"/bot-co38-k-base.log -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n 1)
	if [[ -n $newest ]]; then
		bage=$(( now - ${newest%%.*} ))
		echo "bot stage: newest output ${newest#* } written $((bage / 60)) min ago"
		age=$bage
	fi
fi
if grep -q 'bot base rerun done' "$L" 2>/dev/null; then echo "VERDICT: DONE (batch and the bot base rerun)"
elif grep -q 'ALL GAPS DONE' "$L" 2>/dev/null && (( drv > 0 )); then echo "VERDICT: OK (batch done; the bot base rerun is running)"
elif grep -q 'ALL GAPS DONE' "$L" 2>/dev/null; then echo "VERDICT: DEAD (batch done, but no bot base rerun line and no driver)"
elif grep -q 'STOPPED' "$L" 2>/dev/null; then echo "VERDICT: STOPPED ($(grep STOPPED "$L" | tail -n 1))"
elif (( drv == 0 )); then echo "VERDICT: DEAD (no driver process, no done line)"
elif (( age >= 1200 )); then echo "VERDICT: STALE (no progress line for $((age / 60)) min)"
else echo "VERDICT: OK"
fi

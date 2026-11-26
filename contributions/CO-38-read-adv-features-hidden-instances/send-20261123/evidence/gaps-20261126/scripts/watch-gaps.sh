#!/bin/bash
# watch-gaps.sh : event stream for all-gaps.sh (tips3/progress.log), as tmp/kernel-queue-20261123/watch-progress.sh:
# every build, "-full", HUNG, failed, stage-done, bot and STOPPED line, and a STALL line when the log has not grown
# for 20 minutes (a kernel build is quiet for most of that) while a guest, build or container is alive.
set -u
L=<work area>/tips3/progress.log
until [[ -e $L ]]; do sleep 5; done
# Start at the log's current end, so a re-armed watch reports only what is new.
last=$(stat -c %s "$L")
quiet=0
while true; do
	size=$(stat -c %s "$L")
	if (( size > last )); then
		tail -c +$((last + 1)) "$L" | grep -a -E -- 'make rc|-full |HUNG|failed|FAILED|done|no image|bot |STOPPED|ALL GAPS' || true
		last=$size
		quiet=0
	else
		quiet=$((quiet + 30))
		if (( quiet >= 1200 )); then
			# The bot stage writes progress lines only at its start and end: judge it by its own output.
			if tail -n 1 "$L" | grep -q 'bot .* start'; then
				B=/root/exp/qca9377-bt-hang/tmp/kernel-queue-20261126
				n=$(find "$B"/bot-co38-k "$B"/bot-co38-bluez "$B"/bot-co38-k.log "$B"/bot-co38-bluez.log -type f -newermt "$(date -d '-20 min' '+%F %T')" 2>/dev/null | grep -c .)
				(( n > 0 )) || echo "STALL: bot stage wrote nothing for 20 min"
			else
				echo "STALL: progress.log unchanged for $((quiet / 60)) min; alive: $(pgrep -c -f 'test-runner -q|make -C|docker') process(es)"
			fi
			quiet=0
		fi
	fi
	sleep 30
done

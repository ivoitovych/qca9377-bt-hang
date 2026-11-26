#!/bin/bash
# run-gaps.sh : the gaps left in CO-38's suite runs of 2026-11-23 (tips2), closed on 2026-11-26.
#  A. the new bluetooth-next tip (next2, f57f78086ab5): the new case 3 times on base and co38, then all 11 BlueZ
#     testers the upstream kernel CI lists (the 10 of tips2 plus 6lowpan), in full, on both;
#  B. 6lowpan-tester on the 7 tips2 trees, base and co38;
#  C. the cases a hang cut off on both sides in tips2: l2cap on 6.18, 6.12 and 6.6, iso on 6.12; each case after
#     the hung one, alone (tester -s), on base and co38.
# Same BlueZ build as tips2 (f6fc1a152: 1608f8361 + the CO-38 test), same runner, same hang watchdog as
# tmp/kernel-queue-20261123/run-tips.sh. Logs: $W3/runs/<tree>-<v>-<what>.log; progress in $W3/progress.log.
set -u
W=<work area>
W2=$W/tips2
W3=$W/tips3
B=$W/bluez
Q=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/qemu-smp.sh
CA=/root/exp/qca9377-bt-hang/tmp/kernel-queue-20261126/cases-after.py
mkdir -p "$W3/runs" "$W3/lists"
say() { echo "$(date -u '+%F %T') UTC $*" | tee -a "$W3/progress.log"; }
run() { # <log> <cmd...>   (IMG must be set)
	local log=$1; shift
	[[ -e $log ]] && return 0
	# stdin from /dev/null: inside the while-read loop of stage C the guest otherwise reads the rest of the case
	# list (2026-11-26: only the first case of each list ran before this was added).
	(cd "$B" && exec nice -n 19 timeout 1800 "$B/tools/test-runner" -q "$Q" -k "$IMG" -- "$@") < /dev/null > "$log" 2>&1 &
	local pid=$! hung=""
	while kill -0 "$pid" 2>/dev/null; do
		if grep -a -q -E 'blocked for more than (6[0-9]|[7-9][0-9]|[0-9]{3,}) seconds' "$log"; then
			hung=$(sed -e 's/\x1b\[[0-9;]*m//g' "$log" | grep -a -E ' - run$' | tail -n 1 | sed -e 's/ - run$//')
			kill -TERM "$pid" 2>/dev/null
			break
		fi
		sleep 10
	done
	wait "$pid"
	local rc=$?
	if [[ -n $hung ]]; then
		echo "HUNG in: $hung (guest stopped by the watchdog after a 60 s hung-task report)" >> "$log"
		say "$(basename "$log" .log) HUNG in \"$hung\""
		return 0
	fi
	say "$(basename "$log" .log) rc=$rc $(sed -e 's/\x1b\[[0-9;]*m//g' "$log" | grep -a -E '^Total:' | tail -n 1)"
}
TESTERS=(bnep iso l2cap mgmt rfcomm sco ioctl mesh smp userchan 6lowpan)
say "gaps start"

# A. next2
for v in base co38; do
	IMG=$W3/img/bzImage-next2-$v
	[[ -e $IMG ]] || { say "A: no image $IMG"; continue; }
	for k in 1 2 3; do
		run "$W3/runs/next2-$v-co38-case$k.log" "$B/tools/mgmt-tester" -s '"Read Advertising Features - Success 3 (Instance 2 only)"'
	done
	for s in "${TESTERS[@]}"; do
		run "$W3/runs/next2-$v-$s-full.log" "$B/tools/$s-tester"
	done
done
say "A done (next2)"

# B. 6lowpan on the tips2 trees
for t in next main 7.3 6.18 6.12 6.6 6.1; do
	for v in base co38; do
		IMG=$W2/img/bzImage-$t-$v
		[[ -e $IMG ]] || { say "B: no image $IMG"; continue; }
		run "$W3/runs/$t-$v-6lowpan-full.log" "$B/tools/6lowpan-tester"
	done
done
say "B done (6lowpan)"

# C. the cases after the hangs, one by one. The list comes from tips2's complete next-base run (same BlueZ build).
python3 -I "$CA" "$W2/runs/next-base-l2cap-full.log" "L2CAP Ext-Flowctl Server - Accept 2 Close 1" > "$W3/lists/l2cap-after.txt" || { say "C: l2cap list failed"; exit 1; }
python3 -I "$CA" "$W2/runs/next-base-iso-full.log" "ISO Broadcaster Receiver Defer Get BASE - Success" > "$W3/lists/iso-after.txt" || { say "C: iso list failed"; exit 1; }
after() { # <tree> <tester> <list>
	local t=$1 s=$2 list=$3 v n name pat
	for v in base co38; do
		IMG=$W2/img/bzImage-$t-$v
		[[ -e $IMG ]] || { say "C: no image $IMG"; continue; }
		n=0
		while IFS= read -r name; do
			n=$((n + 1))
			# A double space may not survive the guest's command line: match on the part before it.
			pat=${name%%  *}
			run "$W3/runs/$t-$v-$s-after$(printf '%02d' "$n").log" "$B/tools/$s-tester" -s "\"$pat\""
		done < "$list"
	done
}
for t in 6.18 6.12 6.6; do after "$t" l2cap "$W3/lists/l2cap-after.txt"; done
after 6.12 iso "$W3/lists/iso-after.txt"
say "C done (after the hangs)"
say "gaps runs done"

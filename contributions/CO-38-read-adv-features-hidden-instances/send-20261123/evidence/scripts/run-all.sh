#!/bin/bash
# run-all.sh [line...] : for each line (default all six) with both images built, run the testers in a
# 4-vCPU test-runner guest on base and patched: the two new cases alone, full mgmt-tester and mesh-tester;
# on "next" also l2cap-tester and smp-tester. One guest at a time, low priority. Skips logs that exist.
set -u
R=/root/exp/qca9377-bt-hang
W=${KQ_WORK:?set KQ_WORK to the work area (worktree, images, logs)}
B=$W/bluez
Q=$R/tmp/mesh-tester-ci/qemu-smp.sh
mkdir -p "$W/runs"
say() { echo "$(date -u '+%F %T') UTC $*" | tee -a "$W/progress.log"; }
run() { # <log> <limit s> <image> <cmd...>
	local log=$1 lim=$2 img=$3; shift 3
	[[ -e $log ]] && return 0
	echo "start $(date -u '+%F %T') UTC kernel $img cmd $*" > "$log.part"
	(cd "$B" && nice -n 19 timeout "$lim" "$B/tools/test-runner" -q "$Q" -k "$img" -- "$@") >> "$log.part" 2>&1
	echo "exit=$? end $(date -u '+%F %T') UTC" >> "$log.part"
	mv "$log.part" "$log"
}
lines=("$@"); [[ ${#lines[@]} -eq 0 ]] && lines=(next 7.3 6.18 6.12 6.6 6.1)
for l in "${lines[@]}"; do
	for v in base patched; do
		img=$W/img/bzImage-$l-$v
		[[ -r $img ]] || { say "run $l $v: no image, skipped"; continue; }
		say "run $l $v start"
		# test-runner joins its arguments into one sh command line: quote the case names for that shell with DOUBLE quotes (it passes them inside single quotes)
		for k in 1 2 3; do
			run "$W/runs/$l-$v-co38-case$k.log" 300 "$img" "$B/tools/mgmt-tester" -s '"Read Advertising Features - Success 3 (Instance 2 only)"'
			run "$W/runs/$l-$v-co44-case$k.log" 300 "$img" "$B/tools/mgmt-tester" -s '"Set Device Class - Timeout 1"'
		done
		run "$W/runs/$l-$v-mgmt-full.log" 3600 "$img" "$B/tools/mgmt-tester"
		run "$W/runs/$l-$v-mesh-full.log" 1800 "$img" "$B/tools/mesh-tester"
		if [[ $l == next ]]; then
			run "$W/runs/$l-$v-l2cap-full.log" 3600 "$img" "$B/tools/l2cap-tester"
			run "$W/runs/$l-$v-smp-full.log" 1800 "$img" "$B/tools/smp-tester"
		fi
		say "run $l $v done"
	done
done
say "runs done: ${lines[*]}"

#!/bin/bash
# run-clamp.sh <first> <last> - CO-12 clamp guests (KASAN+lockdep, 4 CPUs), interleaved per run, one guest at a time.
#  AdvDur   : research mgmt-tester (22 AdvDur cases of the 11-01 draft, rebuilt on BlueZ master) on plain, clamp
#  Add      : the CO-38 series mgmt-tester -p Add (128 cases) on plain, fix, clamp, clampfix
#  Adv      : master mgmt-tester (4dc15be8) -s Advertising on plain, clamp
# Logs CO-12/logs/<set>-<image>-<n>.log
set -u
W=/root/exp/agent-work/lane3-mgmt-20261114
L=$W/CO-12/logs
B=$W/CO-12/bin
for n in $(seq "$1" "$2"); do
	for k in plain clamp; do
		img=$W/CO-38/img/bzImage-plain
		[ "$k" = clamp ] && img=$W/images/bzImage-clamp
		"$W/run-vm.sh" "$L" "AdvDur-$k-$n" "$img" "$B/mgmt-tester-advdur" -p AdvDur
	done
	for k in plain fix clamp clampfix; do
		case $k in
		plain) img=$W/CO-38/img/bzImage-plain ;;
		fix) img=$W/CO-38/img/bzImage-fix ;;
		*) img=$W/images/bzImage-$k ;;
		esac
		"$W/run-vm.sh" "$L" "Add-$k-$n" "$img" "$W/CO-38/bin/mgmt-tester-series" -p Add
	done
	for k in plain clamp; do
		img=$W/CO-38/img/bzImage-plain
		[ "$k" = clamp ] && img=$W/images/bzImage-clamp
		"$W/run-vm.sh" "$L" "Adv-$k-$n" "$img" /root/exp/qca9377-bt-hang/tmp/co05-w4/bin/mgmt-tester-master-4dc15be8 -s Advertising
	done
done
echo "$(date +%H:%M:%S) clamp runs $1..$2 done" >> "$W/progress.log"

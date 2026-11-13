#!/bin/bash
# run-guest.sh <kernel tag> <run label> <scenario> [emulator args...]
# One QEMU/KVM guest (4 CPUs, the project's qemu-smp.sh wrapper, BlueZ's test-runner with the
# host's root as the guest's root) running scripts/bt17-emu.py <scenario> [args] as its command.
# Log: logs/<tag>-<label>.log (refuses to overwrite); the RESULT and key kernel lines printed.
set -u
ulimit -c 0
w=/root/exp/agent-work/bt17-emu-20261113
tr=/root/exp/agent-work/co20-diag-20261101/bin/test-runner-r3
q=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/qemu-smp.sh
# HOSTCPU=1: the guest gets the host's CPU model (a Ryzen here), for the platform quirk
[ "${HOSTCPU:-0}" = 1 ] && q=$w/scripts/qemu-smp-hostcpu.sh
tag=${1:?usage}
label=${2:?usage}
shift 2
mkdir -p "$w/logs"
log=$w/logs/$tag-$label.log
[ -e "$log" ] && { echo "exists: $log"; exit 2; }
echo "start $(date '+%F %T') kernel $tag label $label args $* cpus ${QEMU_SMP:-4}" >"$log"
sha256sum "$w/img/bzImage-$tag" "$w/scripts/bt17-emu.py" >>"$log"
timeout 300 "$tr" -q "$q" -k "$w/img/bzImage-$tag" -- python3 -I "$w/scripts/bt17-emu.py" "$@" >>"$log" 2>&1
echo "exit=$? end $(date '+%F %T')" >>"$log"
grep -a -E "RESULT|EMU |MGMT (Command|Index)|tx timeout|Failed usb_autopm|Resetting usb|reset-resume|reset full-speed|USB disconnect|descriptor read|can't resume|gone after|failed: -110|btusb_waker|autoresume" "$log"

#!/bin/bash
# run-guest.sh <kernel tag> <run label> <scenario> [emulator args...]
# One QEMU/KVM guest (4 CPUs, the project's qemu-smp.sh wrapper, BlueZ's test-runner with the
# host's root as the guest's root) running harness/bt17-emu.py <scenario> [args] as its command.
# Log: logs/<tag>-<label>.log (refuses to overwrite); the RESULT and key kernel lines printed.
set -u
ulimit -c 0
w=/root/exp/agent-work/bt17-emu-20261113
tr=/root/exp/agent-work/co20-diag-20261101/bin/test-runner-r3
q=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/qemu-smp.sh
# HOSTCPU=1: the guest gets the host's CPU model (a Ryzen here), for the platform quirk
[ "${HOSTCPU:-0}" = 1 ] && q=$w/harness/qemu-smp-hostcpu.sh
tag=${1:?usage}
label=${2:?usage}
shift 2
mkdir -p "$w/logs"
log=$w/logs/$tag-$label.log
[ -e "$log" ] && { echo "exists: $log"; exit 2; }
echo "start $(date '+%F %T') kernel $tag label $label args $* cpus ${QEMU_SMP:-4}" >"$log"
sha256sum "$w/img/bzImage-$tag" "$w/harness/bt17-emu.py" >>"$log"
timeout 300 "$tr" -q "$q" -k "$w/img/bzImage-$tag" -- python3 -I "$w/harness/bt17-emu.py" "$@" >>"$log" 2>&1
runner_rc=$?
# the guest's own verdict is the BT17-EXIT line the emulator prints last (0 = success
# condition held); no such line means the guest did not finish: exit 3
echo "exit=$runner_rc end $(date '+%F %T')" >>"$log"
grep -a -E "RESULT|BT17-EXIT|EMU |MGMT (Command|Index)|command( 0x[0-9a-f]+)? tx timeout|Failed usb_autopm|Resetting usb|reset-resume|reset full-speed|USB disconnect|descriptor read|can't resume|gone after|failed: -110|btusb_waker|autoresume" "$log"
rc=3
verdict=$(grep -a -o -E "BT17-EXIT [01]" "$log" | tail -n 1)
[ "$verdict" = "BT17-EXIT 0" ] && rc=0
[ "$verdict" = "BT17-EXIT 1" ] && rc=1
echo "run-guest: $tag $label verdict=${verdict:-none} exit=$rc"
exit $rc

#!/bin/bash
# run-guest.sh <kernel tag> <run label> <scenario> [emulator args...]
# Copy of the emulator work directory's run-guest.sh (bt17-emu-20261113/harness/run-guest.sh) with
# this task's paths: kernels from co43-ea-send-20261113/img, the harness from stress/harness, logs to
# stress/logs; the guest timeout is GUEST_TIMEOUT (default 300 s; the stress runs pass 900).
# One QEMU/KVM guest (4 CPUs, the project's qemu-smp.sh wrapper, BlueZ's test-runner with the
# host's root as the guest's root) running harness/bt17-emu.py <scenario> [args] as its command.
# Log: stress/logs/<tag>-<label>.log (refuses to overwrite). Exit status: the guest's own verdict
# (the BT17-EXIT line the emulator prints last): 0 or 1; 3 if the guest did not finish.
set -u
ulimit -c 0
w=/root/exp/agent-work/co43-ea-send-20261113
h=$w/stress/harness
tr=/root/exp/agent-work/co20-diag-20261101/bin/test-runner-r3
q=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/qemu-smp.sh
tag=${1:?usage}
label=${2:?usage}
shift 2
mkdir -p "$w/stress/logs"
log=$w/stress/logs/$tag-$label.log
[ -e "$log" ] && { echo "exists: $log"; exit 2; }
echo "start $(date '+%F %T') kernel $tag label $label args $* cpus ${QEMU_SMP:-4}" >"$log"
sha256sum "$w/img/bzImage-$tag" "$h/bt17-emu.py" >>"$log"
timeout "${GUEST_TIMEOUT:-300}" "$tr" -q "$q" -k "$w/img/bzImage-$tag" -- python3 -I "$h/bt17-emu.py" "$@" >>"$log" 2>&1
runner_rc=$?
echo "exit=$runner_rc end $(date '+%F %T')" >>"$log"
grep -a -E "RESULT|BT17-EXIT|PARKED|KERNEL-REPORT|KERNEL-TIMEOUT|WATCHDOG|scenario raised|Failed to resume|command( 0x[0-9a-f]+)? tx timeout" "$log" | grep -a -v "KMSG.*RESULT"
rc=3
verdict=$(grep -a -o -E "BT17-EXIT [01]" "$log" | tail -n 1)
[ "$verdict" = "BT17-EXIT 0" ] && rc=0
[ "$verdict" = "BT17-EXIT 1" ] && rc=1
echo "run-guest: $tag $label verdict=${verdict:-none} exit=$rc"
exit $rc

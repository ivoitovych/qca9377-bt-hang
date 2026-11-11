#!/bin/bash
# run-guest.sh <kernel tag> <scenario> [<run number>]
# One QEMU/KVM guest with 4 CPUs (the SMP wrapper of the project's tmp/mesh-tester-ci),
# the image img/bzImage-<tag>, running scripts/usbip-bt-emu.py <scenario> as the guest's
# command (BlueZ's test-runner from co20-diag, the host's root as the guest's root).
# Log: logs/guest-<tag>-<scenario>-<n>.log (refuses to overwrite).
set -u
ulimit -c 0
w=/root/exp/agent-work/laptop-btusb-modules-20261111
tr=/root/exp/agent-work/co20-diag-20261101/bin/test-runner-r3
q=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/qemu-smp.sh
tag=${1:?usage}
sc=${2:?usage}
n=${3:-1}
mkdir -p "$w/logs"
log=$w/logs/guest-$tag-$sc-$n.log
[ -e "$log" ] && { echo "exists: $log"; exit 2; }
echo "start $(date '+%F %T') kernel $tag scenario $sc run $n cpus ${QEMU_SMP:-4}" >"$log"
sha256sum "$w/img/bzImage-$tag" "$w/scripts/usbip-bt-emu.py" >>"$log"
x=${4:-}
timeout 240 "$tr" -q "$q" -k "$w/img/bzImage-$tag" -- python3 -I "$w/scripts/usbip-bt-emu.py" "$sc" $x >>"$log" 2>&1
echo "exit=$? end $(date '+%F %T')" >>"$log"
grep -a -E "RESULT|STATE|SET_INTERFACE" "$log"

#!/bin/bash
# run-guest-rg.sh <kernel tag> <run label> [rg-emu.py args...]
# As run-guest.sh, with scripts/rg-emu.py (Raw Gadget on dummy_hcd) as the guest's command.
set -u
ulimit -c 0
w=/root/exp/agent-work/bt17-emu-20261113
tr=/root/exp/agent-work/co20-diag-20261101/bin/test-runner-r3
q=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/qemu-smp.sh
tag=${1:?usage}
label=${2:?usage}
shift 2
log=$w/logs/$tag-rg-$label.log
[ -e "$log" ] && { echo "exists: $log"; exit 2; }
echo "start $(date '+%F %T') kernel $tag label rg-$label args $*" >"$log"
sha256sum "$w/img/bzImage-$tag" "$w/scripts/rg-emu.py" >>"$log"
timeout 300 "$tr" -q "$q" -k "$w/img/bzImage-$tag" -- python3 -I "$w/scripts/rg-emu.py" "$@" >>"$log" 2>&1
echo "exit=$? end $(date '+%F %T')" >>"$log"
grep -a -E "RESULT|GADGET event|before sleep|back from freeze|no reset_resume|reset_resume|Resetting usb|reset full-speed|USB disconnect|failed to suspend|Traceback|Error|no hci0" "$log"

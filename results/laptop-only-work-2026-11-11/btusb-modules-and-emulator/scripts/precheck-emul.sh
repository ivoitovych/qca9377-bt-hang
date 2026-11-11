#!/bin/bash
# precheck-emul.sh <pair dir>
# The checks of scripts/module-updates.sh (precheck) that need no modprobe and write nothing,
# repeated here for the pair directory: vermagic, module names, SHA256SUMS, the Module.symvers
# against the module's own __crc_ symbols (nm); the dependants' CRCs are modcrc.py's.
set -u
d=${1:?usage}
KREL=7.0.0-42-generic
rc=0
for m in bluetooth btusb; do
	ko=$d/$m.ko
	[[ "$(modinfo -F vermagic "$ko" | cut -d' ' -f1)" == "$KREL" ]] && echo "vermagic ok: $m" || { echo "VERMAGIC WRONG: $m"; rc=1; }
	[[ "$(modinfo -F name "$ko")" == "$m" ]] && echo "name ok: $m" || { echo "NAME WRONG: $m"; rc=1; }
done
(cd "$d" && sha256sum --quiet -c SHA256SUMS) && echo "SHA256SUMS ok" || { echo "SHA256SUMS WRONG"; rc=1; }
if diff -q <(nm "$d/bluetooth.ko" | sed -n 's/.* __crc_//p' | sort) <(cut -f2 "$d/Module.symvers" | sort) >/dev/null; then
	echo "Module.symvers lists the module's own exports: ok ($(cut -f2 "$d/Module.symvers" | grep -c .) names)"
else
	echo "Module.symvers does NOT list the module's own exports"
	rc=1
fi
python3 -I /root/exp/agent-work/laptop-btusb-modules-20261111/scripts/modcrc.py check "$d/Module.symvers" "$d/btusb.ko" "$d/bluetooth.ko" | tail -n 4 || rc=1
exit $rc

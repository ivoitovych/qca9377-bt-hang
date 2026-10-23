#!/bin/bash
# test-module-checks.sh - tests for the 2026-10-23 fixes of scripts/module-updates.sh (precheck,
# `check`) and scripts/check-modversions.sh. Uses only `check` and check-modversions.sh: nothing is
# installed, nothing under /lib/modules is written. `install` itself is NOT exercised here: this
# session runs as root, so a guard bug would install for real; its trial guard is read, not run.
# Needs tmp/co02-hw/module/series (bluetooth.ko, Module.symvers, SHA256SUMS) and module/base (no
# Module.symvers). Work files in tmp/co02-hw/script-tests/work.
set -u
R=/root/exp/qca9377-bt-hang
MU=$R/scripts/module-updates.sh
CM=$R/scripts/check-modversions.sh
S=$R/tmp/co02-hw/module/series
W=$R/tmp/co02-hw/script-tests/work
rm -rf "$W"; mkdir -p "$W"
pass=0 fail=0
expect() { # <name> <want-rc> <want-regex> <cmd...>
	local name=$1 want=$2 re=$3; shift 3
	local out rc
	out=$("$@" 2>&1); rc=$?
	if [[ $rc -eq $want ]] && grep -qE "$re" <<<"$out"; then
		pass=$((pass + 1)); echo "PASS $name (rc=$rc)"
	else
		fail=$((fail + 1)); echo "FAIL $name (rc=$rc, want $want, /$re/)"; sed -e 's/^/     /' <<<"$out" | tail -n 8
	fi
}
# 1. the good build: every dependant read, E3's updates/btusb.ko among them
expect good-build 0 "^btusb\.ko +uses +[1-9]" "$MU" check "$S/bluetooth.ko"
expect good-build-count 0 "dependants of bluetooth.ko in [^:]+: 33" "$MU" check "$S/bluetooth.ko"
# 2. no Module.symvers beside the module: refused (the old fallback is gone)
expect no-symvers 1 "no Module.symvers beside" "$MU" check "$R/tmp/co02-hw/module/base/bluetooth.ko"
# 3. a Module.symvers that does not list the module's exports
mkdir -p "$W/wrong-names"; cp "$S/bluetooth.ko" "$W/wrong-names/"
sed -e '1d' "$S/Module.symvers" > "$W/wrong-names/Module.symvers"
expect wrong-names 1 "does not list the module's own exports" "$MU" check "$W/wrong-names/bluetooth.ko"
# 4. SHA256SUMS that no longer matches
mkdir -p "$W/bad-sum"; cp "$S/bluetooth.ko" "$S/Module.symvers" "$W/bad-sum/"
printf '%064d  bluetooth.ko\n' 0 > "$W/bad-sum/SHA256SUMS"
expect bad-sum 1 "SHA256SUMS beside .* does not match" "$MU" check "$W/bad-sum/bluetooth.ko"
# 5. a CRC that a dependant disagrees with (hci_register_dev: every HCI driver uses it)
mkdir -p "$W/bad-crc"; cp "$S/bluetooth.ko" "$W/bad-crc/"
awk -F'\t' -v OFS='\t' '$2 == "hci_register_dev" { $1 = "0x00000001" } { print }' "$S/Module.symvers" > "$W/bad-crc/Module.symvers"
expect bad-crc 1 "MISMATCH hci_register_dev" "$MU" check "$W/bad-crc/bluetooth.ko"
# 6. check-modversions: an unreadable module fails instead of counting as clean
expect unreadable 1 "UNREADABLE" "$CM" "$S/Module.symvers" "$W/no-such-module.ko"
# 7. check-modversions: the good case still passes
expect cm-good 0 "OK — every dependant accepts" "$CM" "$S/Module.symvers" /lib/modules/"$(uname -r)"/updates/btusb.ko
# 8. not a bluetooth module
expect wrong-name 1 "is not a bluetooth module" "$MU" check /lib/modules/"$(uname -r)"/updates/btusb.ko
# 9. nothing was installed: updates/ still has no bluetooth.ko
expect nothing-installed 0 "updates/ module: +none" "$MU" status
echo "passed $pass, failed $fail"
(( fail == 0 ))

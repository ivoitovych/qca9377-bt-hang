#!/bin/bash
# check-source.sh: the kernel-source facts the reply to Zijun Hu states, read from mainline
# and bluetooth-next as fetched on the day. Read-only. Run with the kernel cache as $1
# (default: the project's cache/linux).
set -u
tree=${1:-/root/exp/qca9377-bt-hang/cache/linux}
g() { git -C "$tree" "$@"; }

for ref in origin/master bluetooth-next/master; do
    echo "################ $ref = $(g rev-parse --short=12 "$ref")  $(g log -n1 --format=%cI "$ref")"
    f=drivers/bluetooth/btusb_main.c
    g cat-file -e "$ref:$f" 2>/dev/null || f=drivers/bluetooth/btusb.c
    echo "file: $f"

    echo "--- 1. table entries for the three IDs, with their flags line"
    for id in '0x04ca, 0x3015' '0x0cf3, 0xe500' '0x13d3, 0x3503'; do
        g grep -n -A1 -F "USB_DEVICE($id)" "$ref" -- "$f" | sed "s|^$ref:||"
    done

    echo "--- 2. every table line or comment naming QCA9377"
    g grep -n -i 'qca9377' "$ref" -- drivers/bluetooth/ | sed "s|^$ref:||"

    echo "--- 3. the ROM 0x302 entry of qca_devices_table"
    g grep -n -F '0x00000302' "$ref" -- "$f" | sed "s|^$ref:||"

    echo "--- 4. firmware file names and the log line btusb builds"
    g grep -n -E 'rampatch_usb_|nvm_usb_|patch rome 0x|using rampatch file|using NVM file' "$ref" -- "$f" | sed "s|^$ref:||"

    echo "--- 5. hci_qca's mapping of the qca9377 compatible"
    g grep -n -B1 -A1 'qcom,qca9377-bt' "$ref" -- drivers/bluetooth/hci_qca.c | sed "s|^$ref:||"
done

echo "################ commits naming QCA9377 in drivers/bluetooth (mainline)"
g log --format='%h %as %an  %s' -i --grep=qca9377 origin/master -- drivers/bluetooth/

echo "################ Zijun Hu's commits in drivers/bluetooth since 2026-10-01"
for ref in origin/master bluetooth-next/master; do
    echo "-- $ref"
    g log --format='%h %as  %s' --author='Zijun Hu' --since=2026-10-01 "$ref" -- drivers/bluetooth/ net/bluetooth/
done

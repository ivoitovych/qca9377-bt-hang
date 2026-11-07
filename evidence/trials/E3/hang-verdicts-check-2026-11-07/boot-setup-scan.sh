#!/bin/bash
# boot-setup-scan.sh <boot-offset>... — for each boot (journalctl -b offsets), the controller's
# start-up as the kernel logged it: rampatch loaded or not, USB disconnects of the controller's
# port during the first two minutes, and the "Opcode … failed" lines. Journal reads only.
set -uo pipefail
for b in "$@"; do
  first=$(journalctl -b "$b" --no-pager -o short-iso -n 1 --reverse 2>/dev/null | head -0; journalctl -b "$b" --no-pager -o short-iso 2>/dev/null | head -1 | cut -d' ' -f1)
  echo "=== boot $b (first entry $first)"
  journalctl -b "$b" -k --no-pager -o short-iso \
    --grep "QCA: patch rome|using rampatch|usb 3-3: USB disconnect|Opcode 0x[0-9a-f]+ failed|unexpected cc|Controllers:" 2>/dev/null | head -12
done

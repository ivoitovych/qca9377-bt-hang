#!/bin/bash
# boot-bt-summary.sh — one boot's Bluetooth summary, for an exhibit: the boot's
# identity, the btusb build loaded (current boot only), the QCA firmware setup
# lines, every error-level hci0 line (command timeouts, 0x2005, corrupted SCO),
# and the SCO ledger with its totals.
#
#   scripts/boot-bt-summary.sh [<boot>]      boot index or id, as journalctl -b takes it; default 0
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="${1:-0}"
echo "== boot $B"
journalctl --list-boots --no-pager | awk -v b="$B" '$1 == b { print "   " $0 }'
if [[ "$B" == 0 ]]; then
	echo "== btusb loaded now: version $(cat /sys/module/btusb/version 2>/dev/null) srcversion $(cat /sys/module/btusb/srcversion 2>/dev/null)"
fi
echo "== firmware setup (kernel log)"
journalctl -k -b "$B" --no-pager -o short-iso --grep 'rampatch|NVM file|QCA:|E1:' || echo "   (none)"
echo "== error-level hci0 lines (command timeouts, 0x2005, corrupted SCO, unknown handles)"
journalctl -k -b "$B" -p err --no-pager -o short-iso --grep 'hci0' || echo "   (none)"
echo "== SCO ledger"
"$HERE/sco-ledger-boots.sh" "$B"

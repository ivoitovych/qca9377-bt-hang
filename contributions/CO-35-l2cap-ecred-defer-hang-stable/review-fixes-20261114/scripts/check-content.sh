#!/bin/bash
# Content check (does not depend on cgit's log search): fetch the files of the branch tips and grep for what the
# commits add. stable/linux.git (released) and linux-stable-rc.git (release candidates), seven lines.
#   CO-22: 0b05:1868 and 0b05:1825 in drivers/bluetooth/btusb.c
#   CO-35: l2cap_chan_lock_conn / l2cap_chan_close_unlocked in net/bluetooth/l2cap_core.c; the SCI fix
#          (hdev->le_min_rate_interval = rp->min) in net/bluetooth/hci_event.c (7.3 only: no SCI feature elsewhere)
# Controls in the same run: a string every file must contain.
W=/root/exp/agent-work/lane4-bluez-20261114/stable-20261114
F=$W/fetched
UA="qca9377-bt-hang/check"
ST=https://git.kernel.org/pub/scm/linux/kernel/git/stable
stamp=$(date -u '+%Y%m%dT%H%M%SZ')
exec > "$W/logs/content-check-$stamp.txt" 2>&1
echo "content check started $(date -u '+%F %T') UTC"
for repo in linux.git linux-stable-rc.git; do
	echo "== $repo"
	for v in 7.3 6.18 6.12 6.6 6.1 5.15 5.10; do
		tip=$(git ls-remote "$ST/$repo" "refs/heads/linux-$v.y" | cut -c1-12)
		echo "linux-$v.y tip $tip ($(date -u '+%F %T') UTC)"
		get() { curl -s -A "$UA" -o "$F/$3-$repo-$v-$stamp.c" "$ST/$repo/plain/$1?h=linux-$v.y"; }
		get drivers/bluetooth/btusb.c "$v" btusb
		f=$F/btusb-$repo-$v-$stamp.c
		echo "    btusb.c $(wc -c < "$f") bytes: control 'btusb_probe' x$(grep -c 'btusb_probe' "$f"); 0b05:1868 x$(grep -c '0x0b05, 0x1868' "$f"); 0b05:1825 x$(grep -c '0x0b05, 0x1825' "$f")"
		case "$v" in 7.3|6.18|6.12|6.6)
			get net/bluetooth/l2cap_core.c "$v" l2cap_core
			f=$F/l2cap_core-$repo-$v-$stamp.c
			echo "    l2cap_core.c $(wc -c < "$f") bytes: control 'l2cap_chan_del' x$(grep -c 'l2cap_chan_del' "$f"); l2cap_chan_lock_conn x$(grep -c 'l2cap_chan_lock_conn' "$f"); l2cap_chan_close_unlocked x$(grep -c 'l2cap_chan_close_unlocked' "$f")" ;;
		esac
		if [[ $v == 7.3 ]]; then
			get net/bluetooth/hci_event.c "$v" hci_event
			f=$F/hci_event-$repo-$v-$stamp.c
			echo "    hci_event.c $(wc -c < "$f") bytes: control 'hci_cc_le_read_conn_interval' x$(grep -c 'hci_cc_le_read_conn_interval' "$f"); 'le_min_rate_interval = rp->min' x$(grep -c 'le_min_rate_interval = rp->min' "$f")"
		fi
	done
done
echo "content check finished $(date -u '+%F %T') UTC"

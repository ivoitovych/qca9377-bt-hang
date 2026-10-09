#!/bin/bash
# stable-dep-check.sh - phase 5: per stable line, is 71af682ba469 ("Bluetooth:
# mgmt: Dequeue pending mesh_send_sync entries on cancel") there now, under
# which commit and release tag; and is the 2026-09-19 cleanup ("fix mesh_tx
# leak on hci_cmd_sync_queue() failure") anywhere (stable, bluetooth,
# bluetooth-next) after a fresh fetch. Read only (fetches only).
set -u
L=/root/exp/qca9377-bt-hang/cache/linux
git -C "$L" fetch bluetooth
git -C "$L" fetch bluetooth-next
for b in stable/linux-7.2.y stable/linux-6.18.y stable/linux-6.12.y stable/linux-6.6.y stable/linux-6.1.y; do
	c=$(git -C "$L" log -1 --format=%h --grep="Dequeue pending mesh_send_sync entries on cancel" "$b" -- net/bluetooth/mgmt.c)
	if [ -n "$c" ]; then
		echo "$b: $c $(git -C "$L" describe --contains "$c" 2>/dev/null) upstream $(git -C "$L" log -1 --format=%B "$c" | grep -m1 -E 'commit [0-9a-f]{40}|Upstream commit')"
	else
		echo "$b: not present"
	fi
done
for b in bluetooth/master bluetooth-next/master stable/linux-7.2.y stable/linux-6.1.y; do
	echo "$b tip: $(git -C "$L" log -1 --format='%h %ci %s' "$b")"
	echo "  mesh_tx leak cleanup: $(git -C "$L" log -1 --format='%h %s' -i --grep='mesh_tx leak' "$b")"
done
echo "mesh_send() error path at bluetooth-next tip:"
git -C "$L" grep -n -A3 "if (mesh_tx) {" bluetooth-next/master -- net/bluetooth/mgmt.c
git -C "$L" diff --stat 08e90633377f bluetooth/master -- net/bluetooth/mgmt.c net/bluetooth/hci_sync.c net/bluetooth/mgmt_util.c include/net/bluetooth/hci.h include/net/bluetooth/hci_core.h

#!/bin/bash
# Writes CO-36's verbatim excerpts (real addresses) into tmp/co36/raw/; publish only after
# addr-pseudonym.py apply + check. Four cases of PipeWire's delayed HFP volume resend.
set -u
P=/root/exp/qca9377-bt-hang
R=$P/tmp/co36/raw
I=$P/archive/incidents/20261031-momentum-mute-on-at-stop
mkdir -p "$R"

journal() {   # journal <out> <since> <until>
	{
		echo "# journalctl --since \"$2\" --until \"$3\" -o short-precise _COMM=wireplumber _COMM=bluetoothd _COMM=pipewire _COMM=pipewire-pulse + _TRANSPORT=kernel"
		journalctl --no-pager --since "$2" --until "$3" -o short-precise \
			_COMM=wireplumber _COMM=bluetoothd _COMM=pipewire _COMM=pipewire-pulse + _TRANSPORT=kernel
	} > "$R/$1"
}
capture() {   # capture <out> <btsnoop> <from> <to>
	{
		echo "# scripts/capture-window.sh $(basename "$2") \"$3\" \"$4\" 'Synchronous Conn|[+]CIEV|VG[SM]|Disconnect'"
		echo "# (btmon 5.72 decode of the laptop's HCI capture, cut to the window, only packets matching the pattern)"
		"$P/scripts/capture-window.sh" "$2" "$3" "$4" 'Synchronous Conn|[+]CIEV|VG[SM]|Disconnect' 2>/dev/null
	} > "$R/$1"
}

journal A-20261022-2025-connect.journal.txt "2026-10-22 20:25:24" "2026-10-22 20:25:29.2"
capture A-20261022-2025-connect.capture.txt "$P/tmp/co36/hci-20261022-190425.btsnoop" "2026-10-22 20:25:27" "2026-10-22 20:25:30"
journal B-20261023-2353-second-headset.journal.txt "2026-10-23 23:53:10.5" "2026-10-23 23:53:13"
capture B-20261023-2353-second-headset.capture.txt "$P/tmp/co36/hci-20261023-233436.btsnoop" "2026-10-23 23:53:10" "2026-10-23 23:53:14"
journal C-20261031-0258-before-release.journal.txt "2026-10-31 02:58:54.5" "2026-10-31 02:58:57"
capture C-20261031-0258-before-release.capture.txt "$I/hci-20261030-200531-at-0335.btsnoop" "2026-10-31 02:58:54" "2026-10-31 02:58:57"
journal D-20261031-0333-after-release.journal.txt "2026-10-31 03:33:21.8" "2026-10-31 03:33:24.2"
capture D-20261031-0333-after-release.capture.txt "$I/hci-20261031-031927.btsnoop" "2026-10-31 03:33:21" "2026-10-31 03:33:25"
for f in "$R"/*.journal.txt; do
	k=${f%.journal.txt}.key-lines.txt
	{
		echo "# the lines of $(basename "$f") matching:"
		echo "# 'RFCOMM >>|Setting profile|Restoring profile|initial profile|best profile|sco_acquire|acquire complete|released|SCO packet|CREATE_RECORD|CORK_RECORD|DELETE_STREAM|CREATE_PLAYBACK|link Google'"
		grep -E 'RFCOMM >>|Setting profile|Restoring profile|initial profile|best profile|sco_acquire|acquire complete|released|SCO packet|CREATE_RECORD|CORK_RECORD|DELETE_STREAM|CREATE_PLAYBACK|link Google' "$f"
	} > "$k"
done
{
	echo "# python3 -I scripts/hfp-late-vgm-scan.py   (every boot in the journal, 2026-10-31)"
	python3 -I "$P/scripts/hfp-late-vgm-scan.py"
} > "$R/scan-all-boots.txt"
ls -la "$R"

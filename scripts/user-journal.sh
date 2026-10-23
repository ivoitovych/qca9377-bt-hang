#!/bin/bash
# user-journal.sh — read the desktop user's journal (PipeWire, WirePlumber, pipewire-pulse: the
# RFCOMM AT lines and profile switches live there), read-only.
#
#   scripts/user-journal.sh [journalctl read options]...
#   e.g. scripts/user-journal.sh --since "2026-10-23 02:20" -g "Setting profile|AT\+VGM"
#
# Runs `journalctl --user --no-pager -o short-iso-precise` as the desktop user (default `i`;
# BT_DESKTOP_USER overrides). Every search used to be a new `runuser … journalctl` command,
# which no rule covered, so each one prompted (2026-10-23); this script is covered by scripts/*.
# Refuses the options that change the journal or follow it forever.
set -uo pipefail
U="${BT_DESKTOP_USER:-i}"
for a in "$@"; do
	case "$a" in
		--vacuum*|--rotate|--flush|--sync|--relinquish-var|--smart-relinquish-var|--setup-keys|--update-catalog|-f|--follow|--output-fields=*|--cursor-file*)
			echo "user-journal.sh: refused option $a (read-only, bounded reads only)" >&2; exit 2 ;;
	esac
done
exec runuser -u "$U" -- journalctl --user --no-pager -o short-iso-precise "$@"

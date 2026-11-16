#!/bin/bash
# sco-switch-windows.sh — the HCI/RFCOMM packets that decide an HFP codec switch
# made while a SCO link is up, for several switches at once: the AG's +BCS:,
# the Disconnect of the old link (command status and the Disconnection
# Complete EVENT), the headset's AT+BCS= reply, the AG's OK, and whether a
# Setup Synchronous Connection follows. The ordering of the event against the
# reply is the U7 question (docs/issues.md).
#
#   scripts/sco-switch-windows.sh <capture.btsnoop> "<from>" "<to>" [<capture> "<from>" "<to>" …]
#       times as "2026-09-29 02:30:44" (local, as btmon -T prints them)
#
# Read-only; one capture-window.sh call per window, pattern fixed to
# 'Disconn|Synchronous|BCS|4f 4b' (btmon truncates "Disconnect Complete" at
# the column limit, so the stem is matched; 4f 4b is "OK" in the RFCOMM dump).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
(( $# >= 3 && $# % 3 == 0 )) || { echo "usage: sco-switch-windows.sh <capture> <from> <to> [<capture> <from> <to> ...]" >&2; exit 2; }
PAT='Disconn|Synchronous|BCS|4f 4b'
failed=0
while (( $# )); do
	f="$1"; from="$2"; to="$3"; shift 3
	echo "== $(basename "$f")  $from .. $to"
	# capture-window.sh ends in awk `exit` once past the window, so btmon gets
	# SIGPIPE and the pipeline reports 141 under pipefail; that is the normal end.
	# Any other non-zero status is a btmon (or script) failure, and an empty
	# window after it would read as "no switch happened".
	"$HERE/capture-window.sh" "$f" "$from" "$to" "$PAT"; rc=$?
	if (( rc != 0 && rc != 141 )); then
		echo "   NOT READ: capture-window.sh exited $rc for this window; nothing above is its content"
		failed=$((failed + 1))
	fi
	echo
done
if (( failed )); then
	echo "ERROR: $failed window(s) could not be read" >&2
	exit 2
fi

#!/bin/bash
# raw-capture-archive-all.sh — one pass of both raw-capture archivers, for bt-raw-archive.timer.
#
#   scripts/raw-capture-archive-all.sh
#
# 1. bt-trace's captures (/var/log/bt-health/trace/, /root/bt-trace-keep/) into
#    archive/bt-trace/, budget 20 GB (operator, 2026-10-29).
# 2. bt-capture's desktop captures (/var/log/bt-health/capture/hci-*.btsnoop) into
#    archive/hci-capture/, budget 25 GB (operator, 2026-11-13; it was 20 GB from 2026-10-29).
#
# Both are scripts/bt-trace-archive.py: each closed capture is compressed, verified by
# decompression and SHA-256, and listed in its archive's MANIFEST.tsv; nothing is ever
# deleted, and an archive that reaches its budget stops taking files (archive-budget-check.py
# and the session-start hook warn at 80 %). Raising a budget is the operator's call.
#
# WHY A REAL TIMER (2026-11-13): the archiver ran on a transient systemd-run timer, which
# every reboot removed (gone 10-13 → 10-29, and again from the 11-13 morning boot until the
# operator asked for it to survive reboots). bt-capture keeps only its newest 400 files and
# bt-trace prunes by free space, so every hour without the archiver is captures at risk.
#
# Both passes run even if the first fails; the exit status is non-zero if either failed.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rc=0
BT_ARCHIVE_BUDGET_GB=20 BT_ARCHIVE_DIR="$REPO/archive/bt-trace" \
	python3 -I "$REPO/scripts/bt-trace-archive.py" || { echo "bt-trace archive pass failed: $?" >&2; rc=1; }
"$REPO/scripts/desktop-capture-archive.sh" --budget-gb 25 || { echo "desktop capture archive pass failed: $?" >&2; rc=1; }
exit "$rc"

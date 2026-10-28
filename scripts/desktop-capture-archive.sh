#!/bin/bash
# desktop-capture-archive.sh — archive the desktop capture's hci-*.btsnoop files before
# bt-capture's retention deletes them (it keeps the newest 400 files, oldest deleted first).
#
#   scripts/desktop-capture-archive.sh [--once-limit N]
#
# Runs scripts/bt-trace-archive.py on /var/log/bt-health/capture with BT_TRACE_PREFIX=hci-
# into <project>/archive/hci-capture/ (git-ignored, its own MANIFEST.tsv with SHA-256 per
# file). Compresses, verifies by decompressing, never deletes a capture or an archive.
# Budget: 3 GB by default (BT_ARCHIVE_BUDGET_GB overrides); the bt-trace archive's 10 GB is
# the operator's figure for that store, and how much this one may take is the operator's call.
#
# WHY (2026-10-29): the August captures behind EX-055's supported-commands survey and
# EX-031's 08-18 survivor were already gone; on 10-29 386 of 400 slots were used, so the
# 10-10 evening captures were the next to go.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EMPTY="$REPO/tmp/desktop-capture-archive/no-keep-dir"
mkdir -p "$EMPTY"
export BT_TRACE_DIR=/var/log/bt-health/capture
export BT_TRACE_KEEP_DIR="$EMPTY"
export BT_TRACE_PREFIX=hci-
export BT_ARCHIVE_DIR="$REPO/archive/hci-capture"
export BT_ARCHIVE_BUDGET_GB="${BT_ARCHIVE_BUDGET_GB:-3}"
exec python3 -I "$REPO/scripts/bt-trace-archive.py" "$@"

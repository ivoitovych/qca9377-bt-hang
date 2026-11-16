#!/bin/bash
# desktop-capture-archive.sh — archive the desktop capture's hci-*.btsnoop files before
# bt-capture's retention deletes them (it keeps the newest 400 files, oldest deleted first).
#
#   scripts/desktop-capture-archive.sh [--budget-gb N] [--once-limit N]
#
# Runs scripts/bt-trace-archive.py on /var/log/bt-health/capture with BT_TRACE_PREFIX=hci-
# into <project>/archive/hci-capture/ (git-ignored, its own MANIFEST.tsv with SHA-256 per
# file). Compresses, verifies by decompressing, never deletes a capture or an archive.
# Budget: --budget-gb N (BT_ARCHIVE_BUDGET_GB in the environment also works); without
# either, the budget the store already holds (archive/hci-capture/BUDGET_GB), and
# without that the script stops: it has no default of its own. How much this store may take is the operator's call: 10 GB for a one-time run
# over the whole directory, 2026-10-29 (no timer), raised to 20 GB the same night when 10 GB
# filled at 254 of 385 files.
#
# WHY (2026-10-29): the August captures behind EX-055's supported-commands survey and
# EX-031's 08-18 survivor were already gone; on 10-29 386 of 400 slots were used, so the
# 10-10 evening captures were the next to go.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUDGET="${BT_ARCHIVE_BUDGET_GB:-}"
if [[ "${1:-}" == --budget-gb ]]; then
	[[ "${2:-}" =~ ^[0-9]+$ ]] || { echo "usage: desktop-capture-archive.sh [--budget-gb N] [--once-limit N]" >&2; exit 2; }
	BUDGET=$2
	shift 2
fi
# No budget given: the store's own, as the archiver last wrote it (BUDGET_GB in
# the archive directory). A default of this script's own would overwrite that
# file on every run, and the archive the operator raised to 25 GB would read FULL
# in scripts/archive-budget-check.py against a 3 GB it never had. With neither
# a given nor a stored budget there is no number to use: how much the store may
# take is the operator's call.
if [[ -z "$BUDGET" ]]; then
	BUDGET=$(tr -d '[:space:]' < "$REPO/archive/hci-capture/BUDGET_GB" 2>/dev/null || true)
	[[ "$BUDGET" =~ ^[0-9]+(\.[0-9]+)?$ ]] || { echo "desktop-capture-archive: no budget given and none stored in archive/hci-capture/BUDGET_GB; pass --budget-gb N" >&2; exit 2; }
fi
EMPTY="$REPO/tmp/desktop-capture-archive/no-keep-dir"
mkdir -p "$EMPTY"
export BT_TRACE_DIR=/var/log/bt-health/capture
export BT_TRACE_KEEP_DIR="$EMPTY"
export BT_TRACE_PREFIX=hci-
export BT_ARCHIVE_DIR="$REPO/archive/hci-capture"
export BT_ARCHIVE_BUDGET_GB="$BUDGET"
exec python3 -I "$REPO/scripts/bt-trace-archive.py" "$@"

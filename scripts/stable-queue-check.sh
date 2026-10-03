#!/bin/bash
# stable-queue-check.sh — is a patch in the stable team's queue for each line?
# Reads the public stable-queue tree on git.kernel.org (queue-<version>/),
# read-only, and prints QUEUED with the patch file name, or "not in queue".
# For confirming a stable maintainer's "Queued for …" reply against the queue
# itself (operator accounts are leads; the queue is the record).
#
#   scripts/stable-queue-check.sh <patch-file-stem> <version>...
#   e.g. scripts/stable-queue-check.sh bluetooth-btusb-add-imc-networks-qca9377 7.2 6.18 6.12 6.6 6.1 5.15 5.10
#
# A patch leaves queue-<v>/ once that stable release is cut; "not in queue"
# after a release is then checked in releases/<v>.<n>/ (not done here).
set -uo pipefail
STEM="${1:?usage: stable-queue-check.sh <patch-file-stem> <version>...}"; shift
(( $# )) || { echo "usage: stable-queue-check.sh <patch-file-stem> <version>..." >&2; exit 2; }
BASE="https://git.kernel.org/pub/scm/linux/kernel/git/stable/stable-queue.git/tree"
rc=0
for v in "$@"; do
	page=$(curl -s -f "$BASE/queue-$v") || { printf '%-6s ? fetch failed\n' "$v"; rc=1; continue; }
	hit=$(grep -o -E "${STEM}[^'\"<]*\.patch" <<<"$page" | head -1)
	if [[ -n "$hit" ]]; then
		printf '%-6s QUEUED  %s\n' "$v" "$hit"
	else
		printf '%-6s not in queue\n' "$v"
		rc=1
	fi
done
echo "checked $(date -u '+%Y-%m-%d %H:%M UTC') against $BASE/queue-<v>"
exit "$rc"

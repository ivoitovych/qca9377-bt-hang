#!/bin/bash
# stable-rc-check.sh — is a patch in the current stable release candidate of
# each line? Fetches linux-<version>.y from the public linux-stable-rc tree
# into FETCH_HEAD only (no ref is created), then looks for the subject between
# the released tip (stable/linux-<version>.y) and the rc tip. Read-only.
# For the step between QUEUED (scripts/stable-queue-check.sh) and released.
#
#   scripts/stable-rc-check.sh <subject> <version>...
#   e.g. scripts/stable-rc-check.sh "Bluetooth: btusb: Add IMC Networks QCA9377" 6.6 6.1 5.15 5.10
#
# The subject is matched as a fixed string. "not in rc" with an rc tip whose
# subject is a release (no -rc) means no candidate is open for that line.
# LINUX_TREE names the kernel tree when the script runs from a worktree.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBJ="${1:?usage: stable-rc-check.sh <subject> <version>...}"; shift
(( $# )) || { echo "usage: stable-rc-check.sh <subject> <version>..." >&2; exit 2; }
T="${LINUX_TREE:-$HERE/cache/linux}"
RC=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable-rc.git
git -C "$T" fetch -q stable 2>/dev/null || { echo "fetch of stable failed" >&2; exit 2; }
rc=0
for v in "$@"; do
	if ! git -C "$T" fetch -q "$RC" "linux-$v.y" 2>/dev/null; then
		printf '%-6s ? fetch failed\n' "$v"; rc=1; continue
	fi
	tip=$(git -C "$T" rev-parse --short=12 FETCH_HEAD)
	rel="stable/linux-$v.y"
	if ! git -C "$T" merge-base --is-ancestor "$rel" FETCH_HEAD; then
		printf '%-6s ? rc tip %s does not contain %s\n' "$v" "$tip" "$rel"; rc=1; continue
	fi
	head=$(git -C "$T" log -n 1 --format='%s, %cd' --date=short FETCH_HEAD)
	hit=$(git -C "$T" log --format='%h' -F --grep="$SUBJ" "$rel..FETCH_HEAD" | head -1)
	if [[ -n "$hit" ]]; then
		printf '%-6s IN RC  %s  (rc tip %s: %s)\n' "$v" "$hit" "$tip" "$head"
	else
		printf '%-6s not in rc  (rc tip %s: %s)\n' "$v" "$tip" "$head"
		rc=1
	fi
done
echo "checked $(date -u '+%Y-%m-%d %H:%M UTC') against $RC"
exit "$rc"

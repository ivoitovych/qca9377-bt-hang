#!/bin/bash
# checkpatch.sh <patch>...
# The CI bot's CheckPatch: /usr/bin/checkpatch.pl --ignore UNKNOWN_COMMIT_ID
# (bluez/action-ci config.json), run in the bot's image from a BlueZ tree
# (for its .checkpatch.conf). Output: patches/checkpatch.log
set -u
W=/root/exp/agent-work/exit-uaf
IMG=bluez-action-ci:60348956fc7b
out=$W/patches/checkpatch.log
: > "$out"
rc=0
for p in "$@"; do
	echo "== $(basename "$p")" | tee -a "$out"
	docker run --rm --volume "$W:$W" --workdir "$W/repo" \
		--entrypoint /usr/bin/checkpatch.pl "$IMG" \
		--ignore UNKNOWN_COMMIT_ID "$p" 2>&1 | tee -a "$out"
	(( PIPESTATUS[0] == 0 )) || rc=1
done
echo "checkpatch exit $rc" | tee -a "$out"
exit $rc

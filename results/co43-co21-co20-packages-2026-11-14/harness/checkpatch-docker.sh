#!/bin/bash
# checkpatch-docker.sh <patch>...
# The tree's checkpatch --strict on the given patches inside the list bot's Docker image, tree lx
# (read-only); commit ids (Fixes:) resolve in the project's cache/linux (GIT_DIR, read-only), so the
# unknown-commit-id check runs for real. The patches must lie under the work directory.
set -u
l=/root/exp/agent-work/lane1-btusb-20261114
img=${CHECKPATCH_IMAGE:-bluez-action-ci:60348956fc7b}
g=/root/exp/qca9377-bt-hang/cache/linux/.git
for p in "$@"; do
	echo "== checkpatch --strict $p"
	docker run --rm --network none \
		--volume "$l:$l:ro" --volume "$g:$g:ro" \
		--volume /root/exp/agent-work/laptop-btusb-modules-20261111/linux-btnext/.git:/root/exp/agent-work/laptop-btusb-modules-20261111/linux-btnext/.git:ro \
		--env GIT_DIR="$g" --workdir "$l/lx" --entrypoint perl "$img" \
		scripts/checkpatch.pl --strict "$p"
	echo "== exit $?"
done

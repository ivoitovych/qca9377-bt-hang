#!/bin/bash
# checkpatch-docker.sh <patch>...
# The kernel's checkpatch --strict on the given patch files, inside the list bot's Docker image
# (the host must not run the tree's scripts). The tree is this task's bluetooth-next worktree
# (read-only); commit ids such as Fixes: are resolved in the project's cache/linux, which has the
# full mainline history (GIT_DIR, read-only), so the UNKNOWN_COMMIT_ID check runs for real.
set -u
w=/root/exp/agent-work/co43-ea-send-20261113
img=${CHECKPATCH_IMAGE:-bluez-action-ci:60348956fc7b}
g=/root/exp/qca9377-bt-hang/cache/linux/.git
for p in "$@"; do
	echo "== checkpatch --strict $p"
	docker run --rm --network none \
		--volume "$w:$w:ro" --volume "$g:$g:ro" \
		--volume /root/exp/agent-work/laptop-btusb-modules-20261111/linux-btnext/.git:/root/exp/agent-work/laptop-btusb-modules-20261111/linux-btnext/.git:ro \
		--env GIT_DIR="$g" --workdir "$w/linux" --entrypoint perl "$img" \
		scripts/checkpatch.pl --strict "$p"
	echo "== exit $?"
done

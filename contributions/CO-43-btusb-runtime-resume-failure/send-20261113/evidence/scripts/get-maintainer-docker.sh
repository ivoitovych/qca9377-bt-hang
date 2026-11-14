#!/bin/bash
# get-maintainer-docker.sh <patch>...
# The kernel's get_maintainer.pl (default options) on each patch, run at the top of this task's
# bluetooth-next worktree (read-only) inside the list bot's Docker image; the default
# --git-fallback is resolved in the project's cache/linux history (GIT_DIR, read-only).
set -u
w=/root/exp/agent-work/co43-ea-send-20261113
img=${CHECKPATCH_IMAGE:-bluez-action-ci:60348956fc7b}
g=/root/exp/qca9377-bt-hang/cache/linux/.git
for p in "$@"; do
	echo "== get_maintainer.pl $p"
	docker run --rm --network none \
		--volume "$w:$w:ro" --volume "$g:$g:ro" \
		--env GIT_DIR="$g" --workdir "$w/linux" --entrypoint perl "$img" \
		scripts/get_maintainer.pl "$p"
	echo "== exit $?"
done

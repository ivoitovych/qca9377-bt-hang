#!/bin/bash
# get-maintainer-docker.sh <patch>...
# The kernel's get_maintainer.pl (default options) on each patch, run at the top of the work tree
# lx (read-only) inside the list bot's Docker image; --git-fallback resolves in the project's
# cache/linux history (GIT_DIR, read-only). The patches must lie under the work directory.
set -u
l=/root/exp/agent-work/lane1-btusb-20261114
img=${CHECKPATCH_IMAGE:-bluez-action-ci:60348956fc7b}
g=/root/exp/qca9377-bt-hang/cache/linux/.git
for p in "$@"; do
	echo "== get_maintainer.pl $p"
	docker run --rm --network none \
		--volume "$l:$l:ro" --volume "$g:$g:ro" \
		--env GIT_DIR="$g" --workdir "$l/lx" --entrypoint perl "$img" \
		scripts/get_maintainer.pl "$p"
	echo "== exit $?"
done

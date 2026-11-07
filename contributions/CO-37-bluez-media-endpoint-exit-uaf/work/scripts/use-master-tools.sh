#!/bin/bash
# use-master-tools.sh <5.72 tree name> <master tree name>
# Inside the CI image's container (nothing runs on the host): put master's
# test tools (emulator/btvirt, client/bluetoothctl, tools/btmgmt,
# tools/test-runner) in place of 5.72's in runs/<5.72 tree>/src, so that
# the functional harness can drive 5.72's bluetoothd (5.72's btvirt lacks
# --server=PATH, its test-runner the harness's options). The tools
# are only copied here, not run. 5.72's own binaries are kept as
# <name>.5.72.
set -eu
W=/root/exp/agent-work/exit-uaf
IMG=bluez-action-ci:60348956fc7b
dst=$W/runs/$1/src
src=$W/runs/$2/src
docker run --rm --volume "$W:$W" --entrypoint bash "$IMG" -c "
set -eu
for f in emulator/btvirt client/bluetoothctl tools/btmgmt tools/test-runner; do
	[ -e $dst/\$f.5.72 ] || cp -a $dst/\$f $dst/\$f.5.72
	cp -a $src/\$f $dst/\$f
	echo \"\$f: \$(sha256sum $dst/\$f | cut -c1-16) from $2 (5.72's kept as \$f.5.72)\"
done" | tee -a "$W/runs/$1/commits.txt"

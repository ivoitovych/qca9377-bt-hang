#!/bin/sh
# Writes the two local experiment diffs against master 4cfc4711 and the
# sha256 of each variant file. Local experiments only, not for submission.
set -u
W=/root/exp/agent-work/co36-v2v3-20261101
M=/root/exp/agent-work/co36/pw/spa/plugins/bluez5/backend-native.c
for v in v2 v3; do
	{
		echo "# LOCAL EXPERIMENT ONLY (CO-36 variant $v), not a proposed change; base PipeWire 4cfc471123a0e041fcd6fec5887c40dbddd40325"
		diff -u --label a/spa/plugins/bluez5/backend-native.c --label b/spa/plugins/bluez5/backend-native.c "$M" "$W/variants/$v/backend-native.c"
	} > "$W/variants/$v.local-experiment.diff"
done
cmp "$M" "$W/variants/v0/backend-native.c" && echo "v0 identical to master"
sha256sum "$M" "$W"/variants/*/backend-native.c > "$W/variants/SHA256SUMS"
cat "$W/variants/SHA256SUMS"

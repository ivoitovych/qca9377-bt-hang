#!/bin/sh
# Three copies of the co36 master tree (4cfc4711, with build-v0-asan), one
# per variant, so the VM runs never write into another work area; the
# variant's backend-native.c is copied in (newer mtime, so ninja rebuilds
# only the bluez5 plugin). Cores and test mounts of earlier campaigns are
# left out.
set -eu
W=/root/exp/agent-work/co36-v2v3-20261101
for v in v0 v2 v3; do
	echo "$(date +%H:%M:%S) tree $v copy start" >> "$W/progress.log"
	rsync -a \
		--exclude '/*.core' \
		--exclude '__pycache__' \
		--exclude '/test/bluezenv/test_co36_hfp_volume_resend.py' \
		--exclude '/test/bluezenv/co03_plugins.py' \
		--exclude '/test/bluezenv/test_co03_pw.py' \
		--exclude '/*-co36-results.jsonl' \
		--exclude '/.git' \
		--exclude '/build-t005' \
		/root/exp/agent-work/co36/pw/ "$W/pw-$v/"
	cp "$W/variants/$v/backend-native.c" "$W/pw-$v/spa/plugins/bluez5/backend-native.c"
	# every file but backend-native.c must equal the master tree
	diff -rq -x .git -x build-t005 -x build-v0-asan -x '*.core' -x __pycache__ \
		-x test_co36_hfp_volume_resend.py -x co03_plugins.py -x test_co03_pw.py \
		/root/exp/agent-work/co36/pw "$W/pw-$v" || true
	echo "$(date +%H:%M:%S) tree $v copy end" >> "$W/progress.log"
done
sha256sum "$W"/pw-v*/spa/plugins/bluez5/backend-native.c

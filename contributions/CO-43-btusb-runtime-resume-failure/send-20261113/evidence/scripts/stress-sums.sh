#!/bin/bash
# stress-sums.sh: copies the kernel build records into stress/kernels/ and writes stress/SHA256SUMS
# over every file under stress/ (harness, logs, kernel records) and the five guest images in img/.
set -u
w=/root/exp/agent-work/co43-ea-send-20261113
mkdir -p "$w/stress/kernels"
for t in ea-base ea-e ea-base-dbg ea-e-dbg ea-a; do
	cp "$w/img/bzImage-$t.commit" "$w/stress/kernels/"
done
cp "$w/scripts/frag-stress.config" "$w/scripts/build-ea.sh" "$w/scripts/build-all.sh" "$w/stress/kernels/"
diff -u "$w/stress/harness/bt17-emu.orig.py" "$w/stress/harness/bt17-emu.py" >"$w/stress/harness/bt17-emu.diff"
diff -u /root/exp/agent-work/bt17-emu-20261113/harness/run-guest.sh "$w/stress/harness/run-guest.sh" >"$w/stress/harness/run-guest.diff"
cd "$w/stress" || exit 2
find . -type f ! -name SHA256SUMS ! -path "./harness/__pycache__/*" -print0 | sort -z | xargs -0 sha256sum >SHA256SUMS
cd "$w" || exit 2
sha256sum img/bzImage-ea-base img/bzImage-ea-e img/bzImage-ea-base-dbg img/bzImage-ea-e-dbg img/bzImage-ea-a | sed 's#img/#../img/#' >>"$w/stress/SHA256SUMS"
wc -l "$w/stress/SHA256SUMS"

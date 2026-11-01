#!/bin/bash
# build-image.sh <tag> - build a QEMU guest kernel from the worktree
# /root/exp/agent-work/research-mesh/linux-btnext at its current HEAD,
# out-of-tree in /root/exp/agent-work/research-mesh/build/kasan (kept between
# builds, so a second build rebuilds only what changed).
# Config: the mesh agent's config-A-base of 2026-10-29 (BlueZ doc/tester.config
# + the 2026-10-05 SMP/kprobe fragment, KASAN + lockdep), then olddefconfig.
# Output: /root/exp/agent-work/research-mesh/img/{bzImage,config,commit,build}-<tag>.
set -u
R=/root/exp/agent-work/research-mesh
T=$R/linux-btnext
O=$R/build/kasan
CFG=/root/exp/agent-work/mesh/qca9377-bt-hang/tmp/mesh/img/config-A-base
TAG="${1:?tag}"
mkdir -p "$R/img" "$O"
echo "== build $TAG start $(date '+%F %T')" | tee -a "$R/progress.log"
echo "   HEAD $(git -C "$T" log -1 --format='%H %s')"
if [ ! -e "$O/.config" ]; then
	cp "$CFG" "$O/.config"
fi
make -C "$T" O="$O" olddefconfig > "$R/img/olddefconfig-$TAG.log" 2>&1
nice -n 10 make -C "$T" O="$O" -j6 > "$R/img/build-$TAG.log" 2>&1
rc=$?
echo "== build $TAG end $(date '+%F %T') rc=$rc" | tee -a "$R/progress.log"
tail -n 3 "$R/img/build-$TAG.log"
if [ "$rc" = 0 ]; then
	cp "$O/arch/x86/boot/bzImage" "$R/img/bzImage-$TAG"
	cp "$O/.config" "$R/img/config-$TAG"
	git -C "$T" log -1 --format='%H %s' > "$R/img/commit-$TAG"
	git -C "$T" diff HEAD --stat >> "$R/img/commit-$TAG"
	sha256sum "$R/img/bzImage-$TAG"
	grep -E '^(# )?CONFIG_(KASAN|KCSAN|PROVE_LOCKING|SMP|BT|BT_LE)[= ]' "$O/.config"
fi
exit $rc

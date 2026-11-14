#!/bin/bash
# build-kernel.sh <tag> <ref> : build a tester kernel (BlueZ tester config + SMP/KASAN/lockdep of the earlier area,
# 4 CPUs) from lane7's linux clone at <ref>. Images: img/bzImage-<tag>, config-<tag>, bzImage-<tag>.commit.
# Low priority (nice 10, ionice best-effort 7), make -j4. Stops under 25 GB free.
if [[ -z "${L7_LOWPRIO:-}" ]]; then
	export L7_LOWPRIO=1
	exec nice -n 10 ionice -c 2 -n 7 "$0" "$@"
fi
set -u
W=/root/exp/agent-work/lane7-sco-20261114
T=$W/linux
CFG=/root/exp/agent-work/co02-review-20261101/img/config-base
TAG=${1:?usage}; REF=${2:?usage}
OBJ=$W/build/obj
mkdir -p "$OBJ" "$W/img" "$W/logs"
avail_kb=$(df -Pk /root | awk 'NR==2 {print $4}')
if (( avail_kb < 25 * 1024 * 1024 )); then echo "STOP: under 25 GB free"; exit 3; fi
git -C "$T" checkout -q "$REF" || { echo "checkout failed"; exit 1; }
[[ -f "$OBJ/.config" ]] || cp "$CFG" "$OBJ/.config"
make -C "$T" O="$OBJ" ARCH=x86_64 olddefconfig > "$W/logs/kernel-olddefconfig-$TAG.log" 2>&1 || { echo "olddefconfig failed"; exit 1; }
make -C "$T" O="$OBJ" ARCH=x86_64 -j4 bzImage > "$W/logs/kernel-build-$TAG.log" 2>&1
rc=$?
echo "make rc=$rc"
[[ $rc -eq 0 ]] || { grep -a -E "error|Error" "$W/logs/kernel-build-$TAG.log" | tail -n 20; exit 1; }
cp "$OBJ/arch/x86/boot/bzImage" "$W/img/bzImage-$TAG"
cp "$OBJ/.config" "$W/img/config-$TAG"
git -C "$T" log -1 --format='%H %s' > "$W/img/bzImage-$TAG.commit"
grep -a "warning:" "$W/logs/kernel-build-$TAG.log" | grep net/bluetooth >> "$W/img/bzImage-$TAG.commit"
grep -E "^CONFIG_(SMP|NR_CPUS|KASAN|PROVE_LOCKING|DEBUG_ATOMIC_SLEEP)=" "$W/img/config-$TAG" >> "$W/img/bzImage-$TAG.commit"
sha256sum "$W/img/bzImage-$TAG"

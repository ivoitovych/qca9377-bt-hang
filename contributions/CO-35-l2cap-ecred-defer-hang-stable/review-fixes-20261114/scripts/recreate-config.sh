#!/bin/bash
# recreate-config.sh <tag>...
# Task 1: recreate the .config exactly as co35/build.sh does (tester.config + hungtask.config, then
# make ARCH=x86 olddefconfig) in a throwaway source export of the tag, grep the sanitizer options, delete the export.
# Source: lane 5's kernel repository (read only: git archive).
set -u
W=/root/exp/agent-work/lane4-bluez-20261114/stable-20261114
KR=/root/exp/agent-work/lane5-status-stable-20261114/k/repo
CFG=/root/exp/qca9377-bt-hang/cache/co02-w2c-bluez/doc/tester.config
HT=/root/exp/agent-work/co35/refresh-20261101/hungtask.config
for TAG in "$@"; do
	D=$W/cfgtmp-$TAG
	LOG=$W/logs/config-$TAG.txt
	rm -rf "$D"
	mkdir -p "$D"
	nice -n 10 ionice -c 2 -n 7 git -C "$KR" archive -o "$D.tar" "$TAG" || exit 2
	tar -C "$D" -xf "$D.tar" || exit 2
	rm -f "$D.tar"
	cp "$CFG" "$D/.config"
	cat "$HT" >> "$D/.config"
	{
		echo "tag $TAG; tester.config sha256 $(sha256sum "$CFG" | cut -c1-16); hungtask.config sha256 $(sha256sum "$HT" | cut -c1-16)"
		echo "--- make ARCH=x86 olddefconfig"
	} > "$LOG"
	( cd "$D" && nice -n 10 ionice -c 2 -n 7 make ARCH=x86 olddefconfig ) >> "$LOG" 2>&1
	{
		echo "--- grep of the resulting .config"
		grep -E "^(CONFIG_KASAN|CONFIG_KASAN_GENERIC|CONFIG_PROVE_LOCKING|CONFIG_LOCKDEP|CONFIG_DEBUG_LOCK_ALLOC|CONFIG_DEBUG_ATOMIC_SLEEP|CONFIG_DETECT_HUNG_TASK|CONFIG_DEFAULT_HUNG_TASK_TIMEOUT|CONFIG_DEBUG_MUTEXES|CONFIG_PROVE_RCU)=" "$D/.config"
		echo "--- not set / absent:"
		grep -E "^# CONFIG_(KASAN|PROVE_LOCKING|LOCKDEP) is not set" "$D/.config"
	} >> "$LOG"
	cp "$D/.config" "$W/logs/dotconfig-$TAG.txt"
	rm -rf "$D"
	cat "$LOG"
done

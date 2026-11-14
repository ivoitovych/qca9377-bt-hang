#!/bin/bash
# build.sh <tag> <line> <variant> <jobs>
#   variant base | pair | pair-sci (pair-sci only for line 7.3.y)
#   pair: 6.x lines = git apply of the final backport files (send-20261102/<line>/0001,0002);
#         7.3.y = cherry-pick --no-commit of the two mainline commits; pair-sci adds 5874f8d03268 on top.
# BlueZ doc/tester.config + hung-task 20 s, as in the 2026-11-02 package. Output: img/bzImage-<tag>-<variant>
set -u
TAG=${1:?usage}; LINE=${2:?usage}; V=${3:?usage}; J=${4:?usage}
R=/root/exp/qca9377-bt-hang
W=/root/exp/agent-work/lane5-status-stable-20261114/co35
KR=/root/exp/agent-work/lane5-status-stable-20261114/k/repo
T=/root/exp/agent-work/lane5-status-stable-20261114/k/wt-$TAG
PK=$R/contributions/CO-35-l2cap-ecred-defer-hang-stable/send-20261102
CFG=$R/cache/co02-w2c-bluez/doc/tester.config
HT=/root/exp/agent-work/co35/refresh-20261101/hungtask.config
mkdir -p "$W/img" "$W/logs"
say() { echo "$(date -u '+%F %T') UTC build $TAG $V: $*" | tee -a "$W/progress.log"; }
M=refs/mainline
if [[ ! -e $T ]]; then git -C "$KR" worktree add --detach "$T" "$TAG" > /dev/null || exit 2; fi
git -C "$T" reset -q --hard "$TAG" || exit 2
git -C "$T" clean -q -fd
if [[ ! -e $T/.config ]]; then cp "$CFG" "$T/.config"; cat "$HT" >> "$T/.config"; fi
case "$V" in
base) ;;
pair|pair-sci)
	if [[ $LINE == 7.3.y ]]; then
		git -C "$T" cherry-pick --no-commit "$(git -C "$KR" rev-parse $M/608e0b7a675b2affbbf38167cad0fa63d8e064f7)" "$(git -C "$KR" rev-parse $M/32d86e048d8efedb7aa6cbbd3c36c3c435401c92)" || { say "cherry-pick failed"; exit 1; }
		if [[ $V == pair-sci ]]; then git -C "$T" cherry-pick --no-commit "$(git -C "$KR" rev-parse $M/5874f8d03268d34189c6c12c56586b64d26a8bcc)" || { say "sci cherry-pick failed"; exit 1; }; fi
	else
		git -C "$T" apply "$PK/$LINE"/0001-*.patch "$PK/$LINE"/0002-*.patch || { say "apply failed"; exit 1; }
	fi ;;
*) echo "variant?"; exit 2 ;;
esac
say "make start"
cd "$T" || exit 2
make ARCH=x86 olddefconfig > "$W/logs/build-olddefconfig-$TAG-$V.log" 2>&1 || { say "olddefconfig failed"; exit 1; }
make ARCH=x86 -j"$J" > "$W/logs/build-$TAG-$V.log" 2>&1
rc=$?
say "make rc=$rc"
[[ $rc -eq 0 ]] || { grep -a -m 20 -E "error|Error" "$W/logs/build-$TAG-$V.log"; exit 1; }
cp "$T/arch/x86/boot/bzImage" "$W/img/bzImage-$TAG-$V"
{ git -C "$T" log -n 1 --format='base %H %s'; git -C "$T" diff HEAD --stat; } > "$W/img/bzImage-$TAG-$V.commit"
grep -a -E "warning:" "$W/logs/build-$TAG-$V.log" | grep -a "net/bluetooth" > "$W/logs/btwarn-$TAG-$V.log"
say "done"

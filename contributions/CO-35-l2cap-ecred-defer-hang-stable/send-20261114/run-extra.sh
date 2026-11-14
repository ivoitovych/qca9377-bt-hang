#!/bin/bash
# extras on 7.3.4: (a) the pair alone, whole l2cap-tester (expected: stalls in the SCI case); (b) pair + dc1ddc65f06d, the case alone
W=/root/exp/agent-work/lane5-status-stable-20261114/co35
KR=/root/exp/agent-work/lane5-status-stable-20261114/k/repo
T=/root/exp/agent-work/lane5-status-stable-20261114/k/wt-v7.3.4
M=refs/mainline
say() { echo "$(date -u '+%F %T') UTC EXTRA: $*" >> "$W/progress.log"; }
say "pair alone, whole tester, 300 s"
"$W/run-test.sh" "$W/img/bzImage-v7.3.4-pair" "$W/logs/full-v7.3.4-pair.log" 300 all > "$W/logs/summary-full-v7.3.4-pair.txt" 2>&1
say "build pair + dc1ddc65f06d"
git -C "$T" reset -q --hard v7.3.4
git -C "$T" cherry-pick --no-commit "$(git -C "$KR" rev-parse $M/608e0b7a675b2affbbf38167cad0fa63d8e064f7)" "$(git -C "$KR" rev-parse $M/32d86e048d8efedb7aa6cbbd3c36c3c435401c92)" "$(git -C "$KR" rev-parse $M/dc1ddc65f06df44dfcfe51955c82a132acb3ab8d)" > "$W/logs/pick-pair-dc1d.log" 2>&1 || { say "cherry-pick with dc1ddc failed"; exit 1; }
cd "$T" || exit 2
make ARCH=x86 olddefconfig > "$W/logs/build-olddefconfig-v7.3.4-pair-dc1d.log" 2>&1
make ARCH=x86 -j4 > "$W/logs/build-v7.3.4-pair-dc1d.log" 2>&1 || { say "build failed"; exit 1; }
cp arch/x86/boot/bzImage "$W/img/bzImage-v7.3.4-pair-dc1d"
say "run pair-dc1d exact"
"$W/run-test.sh" "$W/img/bzImage-v7.3.4-pair-dc1d" "$W/logs/case-v7.3.4-pair-dc1d.log" 180 exact > "$W/logs/summary-v7.3.4-pair-dc1d.txt" 2>&1
git -C "$T" reset -q --hard v7.3.4
say "EXTRA-DONE"

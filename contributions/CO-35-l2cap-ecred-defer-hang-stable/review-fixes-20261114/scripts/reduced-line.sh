#!/bin/bash
# reduced-line.sh <tag> <line> <ann 0|1>
# Task 3: for one stable line, make the reduced prerequisite (only l2cap_chan_lock_conn() and
# l2cap_chan_unlock_conn() of 608e0b7a675b) plus the unchanged patch 2, build with the CO-35 config
# (tester.config + hungtask.config, olddefconfig), run the deferred-accept case and the whole l2cap-tester,
# then delete the build tree. One build at a time; make -j4 under nice/ionice; stops under 27 GB free.
set -u
TAG=${1:?usage}; LINE=${2:?usage}; ANN=${3:?usage}
R=/root/exp/qca9377-bt-hang
W=/root/exp/agent-work/lane4-bluez-20261114/stable-20261114
K=$W/k
T=$W/wt-$TAG
PK=$R/contributions/CO-35-l2cap-ecred-defer-hang-stable/send-20261114/mail
CFG=$R/cache/co02-w2c-bluez/doc/tester.config
HT=/root/exp/agent-work/co35/refresh-20261101/hungtask.config
OUT=$W/reduced/$LINE
mkdir -p "$W/img" "$W/logs" "$OUT"
say() { echo "$(date -u '+%F %T') UTC reduced $TAG: $*" | tee -a "$W/progress.log"; }
avail=$(df -B1M --output=avail /root | tail -1 | tr -d ' ')
(( avail > 27000 )) || { say "STOP: only $avail MB free"; exit 3; }
rm -rf "$T"
git -C "$K" worktree prune
git -C "$K" worktree add --detach "$T" "$TAG" > /dev/null || exit 2
python3 -I "$W/scripts/mkreduced.py" "$T" "$ANN" || exit 2
if [[ $ANN == 1 ]]; then MSG=$W/msg-reduced-73.txt; else MSG=$W/msg-reduced-6x.txt; fi
git -C "$T" add -A
git -C "$T" -c user.name="Iaroslav Voitovych" -c user.email="yaroslav.voytovych@gmail.com" commit -q \
	--author="Pauli Virtanen <pav@iki.fi>" --date="Sat, 29 Aug 2026 17:19:57 +0300" -F "$MSG" || exit 2
if [[ $ANN == 1 ]]; then P2=$W/upstream/32d86e048d8e.patch; else P2=$(ls "$PK/$LINE"/0002-*.patch); fi
git -C "$T" -c user.name="Iaroslav Voitovych" -c user.email="yaroslav.voytovych@gmail.com" am "$P2" > "$W/logs/reduced-am-$TAG.log" 2>&1 || { say "patch 2 did not apply"; exit 1; }
rm -f "$OUT"/*.patch
git -C "$T" format-patch -2 -o "$OUT" > /dev/null
say "patches written to $OUT"
if [[ $ANN == 1 ]]; then
	git -C "$T" -c user.name="Iaroslav Voitovych" -c user.email="yaroslav.voytovych@gmail.com" am "$W/upstream/5874f8d03268.patch" >> "$W/logs/reduced-am-$TAG.log" 2>&1 || { say "SCI fix did not apply"; exit 1; }
	V=red-sci
else
	V=red
fi
cp "$CFG" "$T/.config"
cat "$HT" >> "$T/.config"
cd "$T" || exit 2
nice -n 10 ionice -c 2 -n 7 make ARCH=x86 olddefconfig > "$W/logs/build-olddefconfig-$TAG-$V.log" 2>&1 || { say "olddefconfig failed"; exit 1; }
cp "$T/.config" "$W/logs/dotconfig-built-$TAG-$V.txt"
say "make start"
nice -n 10 ionice -c 2 -n 7 make ARCH=x86 -j4 > "$W/logs/build-$TAG-$V.log" 2>&1
rc=$?
say "make rc=$rc"
[[ $rc -eq 0 ]] || { grep -a -m 20 -E "error|Error" "$W/logs/build-$TAG-$V.log"; exit 1; }
cp "$T/arch/x86/boot/bzImage" "$W/img/bzImage-$TAG-$V"
grep -a -E "warning:" "$W/logs/build-$TAG-$V.log" | grep -a "net/bluetooth" > "$W/logs/btwarn-$TAG-$V.log"
{ git -C "$T" log --format='%h %an: %s' -4; } > "$W/img/bzImage-$TAG-$V.commit"
cd "$W" || exit 2
# the tree is no longer needed for the runs: remove it before the guests start
git -C "$K" worktree remove --force "$T"
say "tree removed; free $(df -B1M --output=avail /root | tail -1 | tr -d ' ') MB"
"$W/scripts/run-test.sh" "$W/img/bzImage-$TAG-$V" "$W/logs/case-$TAG-$V.log" 180 exact >> "$W/logs/summary-$TAG-$V.txt" 2>&1
"$W/scripts/run-test.sh" "$W/img/bzImage-$TAG-$V" "$W/logs/full-$TAG-$V.log" 900 all >> "$W/logs/summary-full-$TAG-$V.txt" 2>&1
say "done"

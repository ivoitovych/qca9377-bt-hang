#!/bin/bash
# build-bluez-testers.sh - research-sco: two sco-tester builds on BlueZ b0bf49270d44
# (the CO-02 send base), each with one author's test patch applied by git am, unchanged:
#   co01: the CO-01 author's two BlueZ test mails (sco-tester, l2cap-tester)
#   co02: the CO-02 BlueZ test mail as sent
# plus tools/test-runner. Binaries to bin/. No ASan (as the earlier project runs).
set -u
W=/root/exp/agent-work/research-sco
B=$W/bluez-b0bf
L=$W/logs
mkdir -p "$W/bin" "$L"
# Committer identity for git am: a placeholder (the run of 2026-11-01 used a placeholder
# address of the reserved .invalid domain here; replaced to keep addresses out of this area).
G="git -C $B -c user.name=scratch -c user.email=scratch"
echo "start $(date '+%T')"
$G checkout -q --detach b0bf49270d44 || exit 1
$G am -q "$W/patches/co01-v3/bluez-0001-sco-tester.eml" "$W/patches/co01-v3/bluez-0002-l2cap-tester.eml" || { echo "am co01 failed"; exit 1; }
$G log --format='%h %s' -n 3
cd "$B" || exit 2
if [[ ! -f Makefile ]]; then
	libtoolize --copy --force > "$L/bluez-libtoolize.log" 2>&1
	./bootstrap-configure --disable-lsan --disable-asan --disable-ubsan > "$L/bluez-configure.log" 2>&1 || { echo "configure failed"; tail -n 20 "$L/bluez-configure.log"; exit 1; }
fi
make -j6 tools/sco-tester tools/l2cap-tester tools/test-runner > "$L/bluez-make-co01.log" 2>&1 || { echo "make co01 failed"; grep -a error "$L/bluez-make-co01.log" | tail -n 20; exit 1; }
cp tools/sco-tester "$W/bin/sco-tester-co01"
cp tools/l2cap-tester "$W/bin/l2cap-tester-co01"
$G log -1 --format='%H %s' > "$W/bin/sco-tester-co01.commit"
$G checkout -q --detach b0bf49270d44 || exit 1
$G am -q "$W/patches/co02-v7-lore/bluez-0001.eml" || { echo "am co02 failed"; exit 1; }
$G log --format='%h %s' -n 2
make -j6 tools/sco-tester tools/l2cap-tester tools/test-runner > "$L/bluez-make-co02.log" 2>&1 || { echo "make co02 failed"; grep -a error "$L/bluez-make-co02.log" | tail -n 20; exit 1; }
cp tools/sco-tester "$W/bin/sco-tester-co02"
cp tools/l2cap-tester "$W/bin/l2cap-tester-plain"
$G log -1 --format='%H %s' > "$W/bin/sco-tester-co02.commit"
sha256sum "$W/bin/sco-tester-co01" "$W/bin/l2cap-tester-co01" "$W/bin/sco-tester-co02" "$W/bin/l2cap-tester-plain" "$B/tools/test-runner"
echo "end $(date '+%T')"

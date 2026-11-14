#!/bin/bash
# Commit the CO-44 change on bluetooth-next master with the new message, check that the same change
# applies to bluetooth master, and record both results.
set -eu
W=/root/exp/agent-work/co44-send-20261113
L=$W/linux
OLD=/root/exp/qca9377-bt-hang/contributions/CO-44-mgmt-timeout-reported-as-auth-failed/patch/0001-Bluetooth-MGMT-Report-a-timed-out-command-as-MGMT_ST.patch
OUT=$W/logs/kernel-prepare.txt
git -C $L config user.name "Iaroslav Voitovych"
git -C $L config user.email yaroslav.voytovych@gmail.com
{
	echo "== bluetooth-next master"
	git -C $L checkout -q -B co44 bluetooth-next-mirror/master
	git -C $L log -1 --format='base %H %s'
	git -C $L am $OLD
	git -C $L commit -q --amend -F $W/msg/kernel-commit-msg.txt
	git -C $L notes add -f -F $W/msg/kernel-notes.txt HEAD
	git -C $L log -1 --format='patched %H %s'
	git -C $L diff --stat HEAD^ HEAD
	echo "== bluetooth master"
	git -C $L checkout -q -B co44-bluetooth bluetooth/master
	git -C $L log -1 --format='base %H %s'
	git -C $L cherry-pick co44
	git -C $L log -1 --format='patched %H %s'
	echo "diff of the two changes (empty = identical hunks apart from index lines):"
	git -C $L diff co44^ co44 > $W/logs/diff-btnext.txt
	git -C $L diff co44-bluetooth^ co44-bluetooth > $W/logs/diff-bt.txt
	grep -v '^index ' $W/logs/diff-btnext.txt > $W/logs/diff-btnext.noidx
	grep -v '^index ' $W/logs/diff-bt.txt > $W/logs/diff-bt.noidx
	cmp $W/logs/diff-btnext.noidx $W/logs/diff-bt.noidx && echo "identical"
	git -C $L checkout -q co44
} 2>&1 | tee $OUT

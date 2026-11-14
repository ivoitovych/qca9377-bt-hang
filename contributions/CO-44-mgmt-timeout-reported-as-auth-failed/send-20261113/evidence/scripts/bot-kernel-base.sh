#!/bin/bash
# The base side of the kernel bot run, alone: the first run's base workspace failed because the
# --shared clone of the treeless $W/linux lacked objects. Tree: the first run's patched-side clone
# of bluetooth-next (complete objects since 2021-06-01; it holds da3cc0258).
W=/root/exp/agent-work/co44-send-20261113
cd $W/project || exit 2
exec $W/project/scripts/bot-ci-local.sh --side base \
	--tree $W/project/tmp/bot-ci-local/co44-kernel-send-20261113/work/patched/src --cache $W/cache \
	--base da3cc02587c629420603df4395179ec82955c941 \
	--bluez-commit 20ffd285b58facfd1f2478d159a5f941b09d5be1 \
	--out $W/project/tmp/bot-ci-local/co44-kernel-send-20261113-base \
	$W/project/tmp/co44-mails/0001-Bluetooth-MGMT-Report-a-timed-out-command-as-MGMT_ST.patch

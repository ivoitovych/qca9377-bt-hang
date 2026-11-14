#!/bin/bash
# The linux-bluetooth CI bot on the kernel mail: bluetooth-next da3cc0258 (today's tip), BlueZ
# master 20ffd285b, VerifyFixes history from 2021-06-01 (161510ccf91c is from 2021-10).
W=/root/exp/agent-work/co44-send-20261113
cd $W/project || exit 2
exec $W/project/scripts/bot-ci-local.sh --tree $W/linux --cache $W/cache \
	--base da3cc02587c629420603df4395179ec82955c941 \
	--bluez-commit 20ffd285b58facfd1f2478d159a5f941b09d5be1 \
	--history-since 2021-06-01 \
	--out $W/project/tmp/bot-ci-local/co44-kernel-send-20261113 \
	$W/project/tmp/co44-mails/0001-Bluetooth-MGMT-Report-a-timed-out-command-as-MGMT_ST.patch

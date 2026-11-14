#!/bin/bash
# The linux-bluetooth CI bot's user-space checks on the BlueZ mail: BlueZ master 20ffd285b (today's
# tip), TestFunctional booting the patched tester.config kernel (bluetooth-next da3cc0258 + CO-44).
W=/root/exp/agent-work/co44-send-20261113
cd $W/project || exit 2
exec $W/project/scripts/bot-ci-local.sh --space user --cache $W/cache \
	--tree $W/cache/bluez-upstream \
	--base 20ffd285b58facfd1f2478d159a5f941b09d5be1 \
	--kernel-image $W/project/tmp/co44-kernel/bzImage-patched \
	--out $W/project/tmp/bot-ci-local/co44-bluez-send-20261113 \
	$W/project/tmp/co44-mails/0001-mgmt-tester-Add-Set-Device-Class-timeout-test.patch

#!/bin/bash
# git send-email --dry-run for every form of the two mails. Nothing is sent: --dry-run never opens a
# connection. No sendmail and no sendemail.smtpserver on this machine, so git prints
# "Server: localhost" and the RCPT TO lines. Options as the operator's commands in
# send-commands.txt, with --confirm=always replaced by --dry-run --confirm=never.
set -u
W=/root/exp/agent-work/co44-send-20261113
G=(git -C $W/linux send-email --dry-run --confirm=never --suppress-cc=self
	--from "Iaroslav Voitovych <yaroslav.voytovych@gmail.com>")
K=(--to "linux-bluetooth@vger.kernel.org"
	--cc "Marcel Holtmann <marcel@holtmann.org>"
	--cc "Luiz Augusto von Dentz <luiz.dentz@gmail.com>"
	--cc "linux-kernel@vger.kernel.org")
B=(--to "linux-bluetooth@vger.kernel.org"
	--cc "Luiz Augusto von Dentz <luiz.dentz@gmail.com>")
run() {   # run <name> <file> <recipient array name>
	local n=$1 f=$2; local -n r=$3
	{
		echo "\$ git send-email --dry-run --confirm=never --suppress-cc=self --from ... ${r[*]} $f"
		"${G[@]}" "${r[@]}" "$f"
		echo "exit $?"
	} > $W/logs/dry-run-$n.txt 2>&1
}
run kernel-as-packaged $W/package/kernel/0001-Bluetooth-MGMT-Report-a-timed-out-command-as-MGMT_ST.patch K
run kernel-A-with-sob $W/controls/kernel-with-sob-local-check-only.patch K
run kernel-B-ccstable-with-sob $W/controls/kernel-ccstable-with-sob-local-check-only.patch K
run bluez $W/package/bluez/0001-mgmt-tester-Add-Set-Device-Class-timeout-test.patch B
grep -H -E "^(Server|MAIL FROM|RCPT TO|To|Cc|From|Subject|exit|Dry-OK|Result)" $W/logs/dry-run-*.txt

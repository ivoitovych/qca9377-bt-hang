#!/bin/bash
# git send-email --dry-run for the three ready kernel/BlueZ packages of 2026-11-13
# (CO-44 kernel + BlueZ test, CO-43's E and A). Nothing is sent: --dry-run opens no
# connection, and this machine has no sendemail.smtpserver configured.
# Output: one log per mail beside this script, then a summary of the envelope lines.
set -u
D=$(dirname "$(readlink -f "$0")")
FROM="Iaroslav Voitovych <yaroslav.voytovych@gmail.com>"
CO44=/root/exp/agent-work/co44-send-20261113
EA=/root/exp/agent-work/co43-ea-send-20261113/package
# From the project checkout: its local config carries the committer identity git needs.
G=(git -C /root/exp/qca9377-bt-hang send-email --dry-run --confirm=never --from "$FROM")
run() {   # run <name> <patch> <args...>
	local n=$1 f=$2; shift 2
	{
		echo "\$ git send-email --dry-run --confirm=never --from ... $* $f"
		"${G[@]}" "$@" "$f"
		echo "exit $?"
	} > "$D/dry-run-$n.txt" 2>&1
}
# CO-44, as send-commands.txt gives them (with --suppress-cc=self).
run co44-kernel "$CO44/package/kernel/0001-Bluetooth-MGMT-Report-a-timed-out-command-as-MGMT_ST.patch" \
	--suppress-cc=self \
	--to "linux-bluetooth@vger.kernel.org" \
	--cc "Marcel Holtmann <marcel@holtmann.org>" \
	--cc "Luiz Augusto von Dentz <luiz.dentz@gmail.com>" \
	--cc "linux-kernel@vger.kernel.org"
# The same command on local copies that carry a Signed-off-by (form A) and also the
# Cc: stable trailer (form B): what the envelope becomes once the operator signs.
for form in with-sob ccstable-with-sob; do
	run "co44-kernel-$form" "$CO44/controls/kernel-$form-local-check-only.patch" \
		--suppress-cc=self \
		--to "linux-bluetooth@vger.kernel.org" \
		--cc "Marcel Holtmann <marcel@holtmann.org>" \
		--cc "Luiz Augusto von Dentz <luiz.dentz@gmail.com>" \
		--cc "linux-kernel@vger.kernel.org"
done
run co44-bluez "$CO44/package/bluez/0001-mgmt-tester-Add-Set-Device-Class-timeout-test.patch" \
	--suppress-cc=self \
	--to "linux-bluetooth@vger.kernel.org" \
	--cc "Luiz Augusto von Dentz <luiz.dentz@gmail.com>"
# E and A, as their send-commands.txt give them.
run co43-E "$EA/E/0001-Bluetooth-btusb-Anchor-a-deferred-URB-under-txlock.patch" \
	--to "Marcel Holtmann <marcel@holtmann.org>" \
	--to "Luiz Augusto von Dentz <luiz.dentz@gmail.com>" \
	--to "linux-bluetooth@vger.kernel.org" \
	--cc "Oliver Neukum <oliver@neukum.org>" \
	--cc "linux-kernel@vger.kernel.org"
run co43-A "$EA/A/0001-Bluetooth-btusb-Report-a-failed-runtime-resume-for-d.patch" \
	--to "Marcel Holtmann <marcel@holtmann.org>" \
	--to "Luiz Augusto von Dentz <luiz.dentz@gmail.com>" \
	--to "linux-bluetooth@vger.kernel.org" \
	--cc "linux-kernel@vger.kernel.org"
grep -H -E "^(Server|MAIL FROM|RCPT TO|To:|Cc:|From:|Subject:|exit|Dry-OK|Result)" "$D"/dry-run-*.txt

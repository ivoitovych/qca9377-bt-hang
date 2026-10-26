#!/bin/bash
# send.sh <package send dir> kernel|bluez [--send]
# CO-02's send, one script for the dry run and the real send, so the command that is sent is the
# command that was dry-run. Without --send: git send-email --dry-run (nothing leaves the machine).
# With --send: the real send, git send-email --confirm=always (it asks before each mail). The
# real send is the OPERATOR's to run, on their own decision; this script never runs it by itself.
# Recipients and options as tmp/co02-round3/send-dry-run.sh (the operator's decision of
# 2026-10-22): the list; Marcel Holtmann and Luiz Augusto von Dentz; Cen Zhang; Aldo Ariel
# Panzardo; Hitalo Souza; Pauli Virtanen; stable@ from the patches' trailers; the author's own
# address suppressed. BlueZ: the list, Luiz Augusto von Dentz, Pauli Virtanen.
# Order: kernel first. Then fill-bluez-link.sh with the cover's Message-ID, then bluez. With
# --send, the BlueZ mail is refused while it still has the @KERNEL_SERIES_LINK@ placeholder.
set -u
D=${1:?usage: send.sh <package send dir> kernel|bluez [--send]}
WHAT=${2:?usage: send.sh <package send dir> kernel|bluez [--send]}
MODE=(--dry-run --confirm=never)
CHECK=0
[[ "${3:-}" == --send ]] && MODE=(--confirm=always)
# --check: the guard --send applies, then stop (tests the guard without sending anything)
[[ "${3:-}" == --check ]] && { MODE=(--confirm=always); CHECK=1; }
G=(git -C /root/exp/qca9377-bt-hang/cache/co02-v1)
FROM=(--from "Iaroslav Voitovych <yaroslav.voytovych@gmail.com>")
CC=(--cc "Marcel Holtmann <marcel@holtmann.org>"
    --cc "Luiz Augusto von Dentz <luiz.dentz@gmail.com>"
    --cc "Cen Zhang <zzzccc427@gmail.com>"
    --cc "Aldo Ariel Panzardo <qwe.aldo@gmail.com>"
    --cc "Hitalo Souza <enghitalo@gmail.com>"
    --cc "Pauli Virtanen <pav@iki.fi>")
case "$WHAT" in
kernel)
	(( CHECK )) && { echo "check: nothing to guard for the kernel mails"; exit 0; }
	"${G[@]}" send-email "${MODE[@]}" --suppress-cc=self "${FROM[@]}" \
		--to "linux-bluetooth@vger.kernel.org" "${CC[@]}" \
		"$D"/kernel/0000-cover-letter.patch "$D"/kernel/0001-*.patch "$D"/kernel/0002-*.patch "$D"/kernel/0003-*.patch
	echo "Next: the cover letter's Message-ID above (the [PATCH 0/3] mail) goes to fill-bluez-link.sh." ;;
bluez)
	if grep -q "@KERNEL_SERIES_LINK@" "$D"/bluez/0001-*.patch; then
		if [[ "${MODE[0]}" != --dry-run ]]; then
			echo "refusing: the BlueZ mail still has @KERNEL_SERIES_LINK@; send the kernel series and run fill-bluez-link.sh first"
			exit 2
		fi
		echo "NOTE: dry run with the link placeholder still in the mail (to be filled after the kernel send)"
	fi
	(( CHECK )) && { echo "check: the BlueZ mail is ready to send (link filled)"; exit 0; }
	"${G[@]}" send-email "${MODE[@]}" --suppress-cc=self "${FROM[@]}" \
		--to "linux-bluetooth@vger.kernel.org" \
		--cc "Luiz Augusto von Dentz <luiz.dentz@gmail.com>" \
		--cc "Pauli Virtanen <pav@iki.fi>" \
		"$D"/bluez/0001-*.patch ;;
*) echo "usage: send.sh <package send dir> kernel|bluez [--send]"; exit 2 ;;
esac

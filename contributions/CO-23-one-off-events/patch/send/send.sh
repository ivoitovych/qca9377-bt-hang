#!/bin/bash
# send.sh — CO-23 event 1: the a2dp_reconfig() use-after-free fix and its test, two BlueZ mails.
#
#   send.sh            check the two mails against SHA256SUMS, then git send-email --dry-run
#                      (nothing leaves the machine)
#   send.sh --send     the real send: git send-email --confirm=always (it asks first)
#
# Recipients: the list; Cc Luiz Augusto von Dentz (README.md, "To whom"). --suppress-cc=self, as for
# CO-02 and CO-25 (--suppress-cc=all drops header Cc). The mails are format-patch output and carry
# no To/Cc of their own. Before the send, scripts/pre-send-check.sh against a fresh BlueZ master
# (README.md, "The send"). Sending is the operator's decision, every time.
set -uo pipefail
DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
AUTHOR=yaroslav.voytovych@gmail.com
P1=0001-a2dp-Fix-use-after-free-when-switching-endpoints-dur.patch
P2=0002-test-Cover-A2DP-endpoint-switch-while-Close-is-pendi.patch
case "${1:-}" in
"") MODE=(--dry-run --confirm=never) ;;
--send) MODE=(--confirm=always) ;;
*) echo "usage: send.sh [--send]" >&2; exit 2 ;;
esac

(cd "$DIR" && sha256sum --check --strict SHA256SUMS) || { echo "refusing: the mails differ from SHA256SUMS"; exit 2; }

git -C "$DIR" send-email "${MODE[@]}" --suppress-cc=self \
	--from "Iaroslav Voitovych <$AUTHOR>" \
	--to "linux-bluetooth@vger.kernel.org" \
	--cc "Luiz Augusto von Dentz <luiz.dentz@gmail.com>" \
	"$DIR/$P1" "$DIR/$P2"
rc=$?
if (( rc != 0 )); then
	echo "FAILED: git send-email exited $rc"
	[[ -z "${1:-}" ]] && echo "(dry run: nothing was sent)"
	exit "$rc"
fi

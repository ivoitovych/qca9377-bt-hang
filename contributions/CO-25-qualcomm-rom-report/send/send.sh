#!/bin/bash
# send.sh — CO-25's report to linux-bluetooth, one plain-text mail.
#
#   send.sh            build send/report.eml from drafts/report-v4.txt, lint it, and run
#                      git send-email --dry-run (nothing leaves the machine)
#   send.sh --send     the real send: git send-email --confirm=always (it asks first)
#
# The .eml is the draft with a From header in front; recipients are given here as well as in
# its headers (as for CO-02), with --suppress-cc=self (--suppress-cc=all drops header Cc).
# The only line allowed over 72 columns is the pinned evidence URL: a URL is never broken.
# Sending is the operator's decision, every time.
set -uo pipefail
DIR=/root/exp/qca9377-bt-hang/contributions/CO-25-qualcomm-rom-report
DRAFT="$DIR/drafts/report-v4.txt"
EML="$DIR/send/report.eml"
AUTHOR=yaroslav.voytovych@gmail.com
case "${1:-}" in
"") MODE=(--dry-run --confirm=never) ;;
--send) MODE=(--confirm=always) ;;
*) echo "usage: send.sh [--send]" >&2; exit 2 ;;
esac

{ printf 'From: Iaroslav Voitovych <%s>\n' "$AUTHOR"; cat "$DRAFT"; } > "$EML"
if grep -q '<EVIDENCE' "$EML"; then echo "refusing: the evidence link is still a placeholder"; exit 2; fi
URLS=$(grep -c -E '^https://github\.com/ivoitovych/qca9377-bt-hang/blob/[0-9a-f]{12}/contributions/CO-25-qualcomm-rom-report/EVIDENCE\.md$' "$EML")
[[ "$URLS" == 1 ]] || { echo "refusing: expected one pinned EVIDENCE.md URL, found $URLS"; exit 2; }
URL_LINE=$(grep -n -E '^https://github\.com/' "$EML" | cut -d: -f1)
LINT=$(/root/exp/qca9377-bt-hang/scripts/mail-lint.sh "$EML")
LEFT=$(grep -v -E "^line $URL_LINE: [0-9]+ columns$" <<<"$LINT")
if [[ "$LEFT" != clean:* && -n "$LEFT" ]]; then echo "$LINT"; echo "refusing: mail-lint findings besides the URL line"; exit 2; fi
echo "lint: clean except the URL line ($URL_LINE) by design"
echo "evidence: $(sed -n "${URL_LINE}p" "$EML")"

git -C /root/exp/qca9377-bt-hang send-email "${MODE[@]}" --suppress-cc=self \
	--from "Iaroslav Voitovych <$AUTHOR>" \
	--to "linux-bluetooth@vger.kernel.org" \
	--cc "Marcel Holtmann <marcel@holtmann.org>" \
	--cc "Luiz Augusto von Dentz <luiz.dentz@gmail.com>" \
	--cc "Zijun Hu <zijun.hu@oss.qualcomm.com>" \
	--cc "Shuai Zhang <shuai.zhang@oss.qualcomm.com>" \
	--cc "Bartosz Golaszewski <brgl@kernel.org>" \
	--cc "Tibor Harcsa <silurust@gmail.com>" \
	"$EML"
rc=$?
if (( rc != 0 )); then
	echo "FAILED: git send-email exited $rc"
	[[ -z "${1:-}" ]] && echo "(dry run: nothing was sent)"
	exit "$rc"
fi

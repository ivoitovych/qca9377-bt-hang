#!/bin/bash
R=/root/exp/qca9377-bt-hang
W=/root/exp/agent-work/lane5-status-stable-20261114/co35
exec > "$W/logs/mail-lint-new.log" 2>&1
for e in request-v4-20261114.eml request-sci-7.3.y-20261114.eml; do
	echo "== $e"
	"$R/scripts/mail-lint.sh" "$W/mail/$e"
done
for l in 6.18.y 6.12.y 6.6.y; do
	c=$W/lint/cover-$l-20261114.eml
	sed -e '/^From: /a To: stable@vger.kernel.org' -e '/^-- $/,$d' -e '1{/^From [0-9a-f]\{40\} /d}' "$W/mail/$l/0000-cover-letter-20261114.patch" > "$c"
	echo "== $l cover (checked copy $c)"
	"$R/scripts/mail-lint.sh" "$c"
done
echo "== byte comparison of the patches with the 2026-11-02 package"
for l in 6.18.y 6.12.y 6.6.y; do
	for f in "$W/mail/$l"/0001-*.patch "$W/mail/$l"/0002-*.patch; do
		cmp "$f" "$R/contributions/CO-35-l2cap-ecred-defer-hang-stable/send-20261102/$l/$(basename "$f")" && echo "identical: $l/$(basename "$f")"
	done
done
echo "== subject lengths"
grep -h "^Subject:" "$W/mail/request-v4-20261114.eml" "$W/mail/request-sci-7.3.y-20261114.eml" | awk '{print length($0) ": " $0}'

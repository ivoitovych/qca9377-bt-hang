#!/bin/bash
# checkpatch (tree: v7.3.4) on the two upstream commits, the six backport patches and the SCI commit; mail-lint on the requests
R=/root/exp/qca9377-bt-hang
W=/root/exp/agent-work/lane5-status-stable-20261114/co35
KR=/root/exp/agent-work/lane5-status-stable-20261114/k/repo
K=/root/exp/agent-work/lane5-status-stable-20261114/k/wt-v7.3.4
PK=$R/contributions/CO-35-l2cap-ecred-defer-hang-stable/send-20261102
mkdir -p "$W/lint"
exec > "$W/logs/checks.log" 2>&1
echo "start $(date -u '+%F %T') UTC; checkpatch.pl from tree v7.3.4 ($(git -C "$K" describe --tags --always 2>/dev/null))"
cd "$K" || exit 2
for c in 608e0b7a675b2affbbf38167cad0fa63d8e064f7 32d86e048d8efedb7aa6cbbd3c36c3c435401c92 5874f8d03268d34189c6c12c56586b64d26a8bcc; do
	echo "=== upstream $c"
	git -C "$KR" format-patch -1 --stdout "refs/mainline/$c" > "$W/lint/upstream-${c:0:13}.patch"
	perl scripts/checkpatch.pl --no-color "$W/lint/upstream-${c:0:13}.patch"
	echo "rc=$?"
done
for l in 6.18.y 6.12.y 6.6.y; do
	for f in "$PK/$l"/0001-*.patch "$PK/$l"/0002-*.patch; do
		echo "=== ${f#$R/contributions/CO-35-l2cap-ecred-defer-hang-stable/}"
		perl scripts/checkpatch.pl --no-color "$f"
		echo "rc=$?"
	done
done
echo "===== mail-lint"
for e in request-v3.eml request-sci-7.3.y.eml; do
	echo "== $e (2026-11-02 versions)"
	"$R/scripts/mail-lint.sh" "$PK/$e"
done
for l in 6.18.y 6.12.y 6.6.y; do
	c=$W/lint/cover-$l.eml
	sed -e '/^From: /a To: stable@vger.kernel.org' -e '/^-- $/,$d' -e '1{/^From [0-9a-f]\{40\} /d}' "$PK/$l/0000-cover-letter.patch" > "$c"
	echo "== $l cover (checked copy $c)"
	"$R/scripts/mail-lint.sh" "$c"
done
echo "end $(date -u '+%F %T') UTC"

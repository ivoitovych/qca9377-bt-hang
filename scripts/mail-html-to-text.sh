#!/bin/bash
# mail-html-to-text.sh — a saved Gmail message (HTML) as plain text under tmp/,
# so the CI bot's backtraces can be grepped. Tags stripped, entities decoded,
# <br> and block ends become newlines. Read-only; writes tmp/<basename>.txt.
#
#   scripts/mail-html-to-text.sh <saved-mail.html>       prints the text file's path
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IN="${1:?usage: mail-html-to-text.sh <saved-mail.html>}"
[[ -r "$IN" ]] || { echo "cannot read $IN" >&2; exit 2; }
mkdir -p "$REPO/tmp"
OUT="$REPO/tmp/$(basename "${IN%.html}").txt"
python3 - "$IN" "$OUT" <<'PYEOF'
import html, re, sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding="utf-8", errors="replace").read()
s = re.sub(r"(?is)<(script|style)[^>]*>.*?</\1>", "", s)
s = re.sub(r"(?i)<br\s*/?>", "\n", s)
s = re.sub(r"(?i)</(p|div|tr|td|li|h[1-6]|pre)>", "\n", s)
s = re.sub(r"(?i)<wbr\s*/?>", "", s)
s = re.sub(r"<[^>]+>", "", s)
s = html.unescape(s).replace("\xa0", " ")
s = re.sub(r"[ \t]+\n", "\n", s)
s = re.sub(r"\n{3,}", "\n\n", s)
open(dst, "w", encoding="utf-8").write(s)
print(dst)
PYEOF

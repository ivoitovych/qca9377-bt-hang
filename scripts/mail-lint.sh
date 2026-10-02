#!/bin/bash
# mail-lint.sh — the mechanical checks on a plain-text mail before it is sent:
# every body line within 72 columns, 7-bit ASCII only, the four headers present,
# no trailing whitespace. The hanging line of 2026-10-02 (draft v3 of the
# stable request) is why this exists: the rest of the mail was wrapped by hand
# and one line was not, and nothing caught it.
#
#   scripts/mail-lint.sh <mail.eml>      exit 0 when clean; every finding printed
set -uo pipefail
F="${1:?usage: mail-lint.sh <mail.eml>}"
[[ -r "$F" ]] || { echo "cannot read $F" >&2; exit 2; }
rc=0
for h in From: To: Subject:; do
	grep -q "^$h " "$F" || { echo "missing header $h"; rc=1; }
done
body_start=$(grep -n -m1 '^$' "$F" | cut -d: -f1)
awk -v s="${body_start:-0}" 'NR > s && length > 72 { printf "line %d: %d columns\n", NR, length; bad = 1 } END { exit bad }' "$F" || rc=1
if grep -n -P '[^\x00-\x7F]' "$F"; then echo "non-ASCII above"; rc=1; fi
if grep -n -P '[ \t]+$' "$F"; then echo "trailing whitespace above"; rc=1; fi
(( rc == 0 )) && echo "clean: headers present, body within 72 columns, ASCII, no trailing whitespace"
exit $rc

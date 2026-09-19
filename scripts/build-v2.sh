#!/bin/bash
# build-v2.sh — derive the v2 of both BlueZ patches from the tracked v1 files,
# changing ONLY what the list's CI bot flagged on 2026-09-19 (register §CB):
#
#   - GitLint B3: the C quoted in the commit message was indented with the
#     tree's tabs; every tab in the message part becomes four spaces.
#   - CheckPatch COMMIT_LOG_LONG_LINE: the two quoted kernel fault lines
#     (77 / 78 columns) are re-wrapped at "sp", and the three quoted
#     disassembly lines lose three spaces before "<--" (77 -> 74 columns).
#   - Subject prefix [PATCH BlueZ] -> [PATCH BlueZ v2]; a two-line changelog
#     directly below the "---" separator, where git am discards it.
#
# The diff itself is copied byte for byte; the script refuses to write if the
# part after "---" differs from v1 in anything but the inserted changelog.
# Writes patches/bluez/v2/<same file names>. Deterministic: run it twice, get
# the same bytes. Prepared for the operator's decision (CB-02); nothing here
# sends anything.
#
#   scripts/build-v2.sh
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO/patches/bluez"
DST="$SRC/v2"
mkdir -p "$DST"
rc=0
for p in "$SRC"/0*.patch; do
	out="$DST/$(basename "$p")"
	awk '
		BEGIN { in_msg = 1 }
		in_msg && /^---$/ {
			print
			print "v2: quoted code indented with spaces instead of tabs; the quoted fault"
			print "    lines re-wrapped to 75 columns. No change to the code."
			print ""
			in_msg = 0
			next
		}
		in_msg {
			sub(/^Subject: \[PATCH BlueZ\] /, "Subject: [PATCH BlueZ v2] ")
			gsub(/\t/, "    ")
			# "  bluetoothd[N]: segfault at A ip X sp Y \" + "      error 4 in ..."
			if (match($0, /^  bluetoothd\[[0-9]+\]: segfault at [0-9a-f]+ ip [0-9a-f]+ sp [0-9a-f]+ \\$/)) {
				sp = $0; sub(/ sp [0-9a-f]+ \\$/, " \\", sp)
				held = $0; sub(/^.* sp /, "sp ", held); sub(/ \\$/, "", held)
				print sp
				pending = held
				next
			}
			if (pending != "") {
				# the continuation "      error 4 in bluetoothd[...]" joins the held "sp Y"
				sub(/^ +/, "", $0)
				print "      " pending " " $0
				pending = ""
				next
			}
			if (/^  a69[0-9a-f]+:  /) sub(/   <--/, "<--")
			print
			next
		}
		{ print }
	' "$p" > "$out"
	# The diff must be v1's diff exactly: compare everything after the separator,
	# with the three inserted lines (changelog ×2, blank) removed from v2.
	if ! diff <(awk 'f{print} /^---$/{f=1}' "$p") \
	          <(awk 'f && skip > 0 {skip--; next} f {print} /^---$/{f=1; skip=3}' "$out") >/dev/null; then
		echo "$(basename "$p"): the part after --- changed beyond the changelog — refusing" >&2
		rm -f "$out"; rc=1; continue
	fi
	tabs=$(awk '/^---$/{exit} /\t/' "$out" | wc -l)
	long=$(awk '/^---$/{exit} length > 75' "$out" | wc -l)
	printf '%s  message tabs=%s  lines>75=%s\n' "$out" "$tabs" "$long"
	(( tabs == 0 && long == 0 )) || rc=1
done
exit $rc

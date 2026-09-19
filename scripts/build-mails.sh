#!/bin/bash
# build-mails.sh — produce the two BlueZ patch mails exactly as they will be
# sent: the tracked patch file with its mail note inserted directly below the
# `---` separator (where `git am` discards it), written to tmp/mail/. The
# tracked patches are not modified.
#
#   scripts/build-mails.sh            writes tmp/mail/0001-*.patch, 0002-*.patch
#   BT_PATCH_DIR=patches/bluez/v2 scripts/build-mails.sh
#                                     the same for a v2 directory; a "v2:"
#                                     changelog already under the separator
#                                     stays first, the note follows it
#
# Then:  git send-email --to=linux-bluetooth@vger.kernel.org tmp/mail/0001-*.patch
#        git send-email --to=linux-bluetooth@vger.kernel.org tmp/mail/0002-*.patch
# — two invocations, never a range (patches/bluez/README.md "How to send").
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$HERE/tmp/mail"; rm -rf "$OUT"; mkdir -p "$OUT"
rc=0
PDIR="${BT_PATCH_DIR:-$HERE/patches/bluez}"
for n in 0001 0002; do
    src=$(ls "$PDIR"/"$n"-*.patch) || { echo "no patch $n in $PDIR" >&2; exit 2; }
    note="$HERE/patches/bluez/mail-notes/$n.txt"
    [[ -r "$note" ]] || { echo "no mail note for $n" >&2; exit 2; }
    dst="$OUT/$(basename "$src")"
    # Insert the note after the FIRST line that is exactly "---", then a blank
    # line, so the diffstat follows the note as git format-patch --notes lays it out.
    # If a "v2:" changelog already follows the separator, the note goes after
    # the changelog's closing blank line instead, so the changelog stays first.
    awk -v notefile="$note" '
        BEGIN { while ((getline l < notefile) > 0) note = note l "\n"; done = 0; sep = 0; defer = 0 }
        !sep && /^---$/                            { print; sep = 1; next }
        sep && !done && !defer && /^v[0-9]+: /     { defer = 1; print; next }
        sep && !done && !defer                     { printf "%s\n", note; done = 1; print; next }
        sep && !done && defer && /^$/              { print; printf "%s\n", note; done = 1; next }
        { print }
    ' "$src" > "$dst"
    seps=$(grep -c '^---$' "$dst")
    (( seps == 1 )) || { echo "$n: expected one --- separator, found $seps" >&2; rc=1; }
    grep -q "^Signed-off-by:" "$dst" && { echo "$n: carries Signed-off-by — BlueZ rejects it" >&2; rc=1; }
    printf '%s\n' "$dst"
    # Show the region around the separator so the placement can be eyeballed.
    awk '/^---$/ {p=1} p && n<14 {print "    " $0; n++}' "$dst"
done
exit $rc

#!/bin/bash
# gates-bluez-final.sh - phase 5 §G: gitlint and BlueZ checkpatch on the final
# BlueZ export (7c62b76f4), plus the line lengths of both cover letters.
set -u
R=/root/exp/qca9377-bt-hang
exec > "$R/tmp/mesh-tester-ci/logs/phase5/gates-bluez-final.log" 2>&1
O=$R/tmp/mesh-tester-ci/series-v3
echo "### gitlint $(date '+%F %T')"
"$R/scripts/gitlint-check.sh" "$R/cache/bluez-upstream" "$O"/bluez/000[1-9]-*.patch
echo "### checkpatch $(date '+%F %T')"
rm -rf "$O/bluez-checkpatch-input-7c62b76f4"
mkdir -p "$O/bluez-checkpatch-input-7c62b76f4"
cp "$O"/bluez/000[1-9]-*.patch "$O/bluez-checkpatch-input-7c62b76f4/"
BT_PATCH_DIR="$O/bluez-checkpatch-input-7c62b76f4" "$R/patches/bluez/checkpatch-check.sh" "$R/cache/bluez-upstream" "$R/cache/full-bt-next/scripts/checkpatch.pl"
echo "### cover letters, lines over 72 columns $(date '+%F %T')"
for c in "$O/0000-cover-letter.patch" "$O/bluez/0000-cover-letter.patch"; do
	echo "== $c"
	awk 'length($0) > 72 { print FILENAME ":" NR ": " length($0) }' "$c"
done
echo "### done $(date '+%F %T')"

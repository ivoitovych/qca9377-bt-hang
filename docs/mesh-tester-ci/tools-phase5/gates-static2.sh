#!/bin/bash
# gates-static2.sh - phase 5 §G, second part, on the final export:
#   1. kernel checkpatch --strict --codespell totals per patch file
#   2. BlueZ gitlint and checkpatch on series-v3/bluez (tester 6640247e6)
#   3. stable: fetch (read only), cumulative text application of the series
#      alone and after 71af682ba469 (series-backport-check-local.sh)
#   4. recipients with scripts/get-maintainers.sh per kernel patch
set -u
R=/root/exp/qca9377-bt-hang
exec > "$R/tmp/mesh-tester-ci/logs/phase5/gates-static2.log" 2>&1
O=$R/tmp/mesh-tester-ci/series-v3
FT=$R/cache/full-bt-next
CP=$FT/scripts/checkpatch.pl
DEP=$R/tmp/mesh-tester-ci/series-v2/deps/0001-Bluetooth-mgmt-Dequeue-pending-mesh_send_sync-entrie.patch
STABLE=stable/linux-7.2.y,stable/linux-6.18.y,stable/linux-6.12.y,stable/linux-6.6.y,stable/linux-6.1.y

echo "### 1. kernel checkpatch --strict --codespell $(date '+%F %T')"
for p in "$O"/000[1-9]-*.patch "$O"/alternative/0001-*.patch; do
	echo "== $(basename "$p")"
	perl "$CP" --strict --codespell --ignore UNKNOWN_COMMIT_ID "$p" | grep -E '^(total|WARNING|ERROR|CHECK)'
done

echo "### 2. BlueZ gitlint $(date '+%F %T')"
"$R/scripts/gitlint-check.sh" "$R/cache/bluez-upstream" "$O"/bluez/000[1-9]-*.patch
echo "### 2b. BlueZ checkpatch $(date '+%F %T')"
rm -rf "$O/bluez-checkpatch-input-final"
mkdir -p "$O/bluez-checkpatch-input-final"
cp "$O"/bluez/000[1-9]-*.patch "$O/bluez-checkpatch-input-final/"
BT_PATCH_DIR="$O/bluez-checkpatch-input-final" "$R/patches/bluez/checkpatch-check.sh" "$R/cache/bluez-upstream" "$CP"

echo "### 3. stable $(date '+%F %T')"
git -C "$R/cache/linux" fetch stable
for b in ${STABLE//,/ }; do git -C "$R/cache/linux" log -1 --format="$b %h %ci %s" "$b"; done
echo "-- series alone"
"$R/tmp/mesh-tester-ci/series-backport-check-local.sh" "$STABLE" "$O"/000[1-9]-*.patch
echo "-- 71af682ba469 first"
head -n 4 "$DEP"
"$R/tmp/mesh-tester-ci/series-backport-check-local.sh" "$STABLE" "$DEP" "$O"/000[1-9]-*.patch
echo "-- 71af682ba469 first, without the droppable 5/5"
"$R/tmp/mesh-tester-ci/series-backport-check-local.sh" "$STABLE" "$DEP" "$O"/000[1-4]-*.patch

echo "### 4. recipients $(date '+%F %T')"
for p in "$O"/000[1-9]-*.patch; do
	echo "== $(basename "$p")"
	"$R/scripts/get-maintainers.sh" "$FT" "$p"
done
echo "### done $(date '+%F %T')"

#!/bin/bash
# make-mails.sh : mails for layout (a) (kernel 1+2 as v2 0/2, patch 3 alone) and layout (b) (kernel v2 0/3),
# and the BlueZ mails of both layouts. Author Iaroslav Voitovych <yaroslav.voytovych@gmail.com>, no Signed-off-by.
W=/root/exp/agent-work/lane7-sco-20261114
K=$W/linux
B=$W/bluez
BASE=da3cc02587c629420603df4395179ec82955c941
BBASE=20ffd285b58facfd1f2478d159a5f941b09d5be1
OUT=$W/mails
rm -rf "$OUT"
mkdir -p "$OUT/b-three/kernel" "$OUT/a-two-plus-one/kernel-v2-1-2" "$OUT/a-two-plus-one/kernel-patch-3" "$OUT/b-three/bluez" "$OUT/a-two-plus-one/bluez-1" "$OUT/a-two-plus-one/bluez-2"

# (b) three kernel patches
git -C "$K" format-patch -v2 --notes --cover-letter --base=$BASE -o "$OUT/b-three/kernel" $BASE..l7-ab || exit 1
python3 -I "$W/scripts/fill-cover.py" "$OUT/b-three/kernel/v2-0000-cover-letter.patch" "[PATCH v2 0/3] Bluetooth: hci_conn: fix SCO connection reuse" "$W/msg/cover-b.txt" || exit 1

# (a) patches 1 and 2 as v2, patch 3 alone
git -C "$K" format-patch -v2 --notes --cover-letter --base=$BASE -o "$OUT/a-two-plus-one/kernel-v2-1-2" $BASE..l7-ab~1 || exit 1
python3 -I "$W/scripts/fill-cover.py" "$OUT/a-two-plus-one/kernel-v2-1-2/v2-0000-cover-letter.patch" "[PATCH v2 0/2] Bluetooth: hci_conn: fix SCO connection reuse" "$W/msg/cover-a12.txt" || exit 1
git -C "$K" format-patch --notes=layout-a3 -o "$OUT/a-two-plus-one/kernel-patch-3" l7-ab~1..l7-ab || exit 1

# BlueZ: (b) 2 patches with cover; (a) patch 1 alone, patch 2 alone
git -C "$B" format-patch -v2 --subject-prefix="PATCH BlueZ" --notes --cover-letter --base=$BBASE -o "$OUT/b-three/bluez" $BBASE..co02-v2 || exit 1
python3 -I "$W/scripts/fill-cover.py" "$OUT/b-three/bluez/v2-0000-cover-letter.patch" "[PATCH BlueZ v2 0/2] tools/sco-tester: Add SCO reconnect tests" "$W/msg/cover-bluez-b.txt" || exit 1
git -C "$B" format-patch -v2 --subject-prefix="PATCH BlueZ" --notes=layout-a1 --base=$BBASE -o "$OUT/a-two-plus-one/bluez-1" $BBASE..co02-v2~1 || exit 1
git -C "$B" format-patch --subject-prefix="PATCH BlueZ" --notes=layout-a3 -o "$OUT/a-two-plus-one/bluez-2" co02-v2~1..co02-v2 || exit 1

python3 -I "$W/scripts/strip-notes-ws.py" "$OUT"/b-three/kernel/*.patch "$OUT"/b-three/bluez/*.patch "$OUT"/a-two-plus-one/kernel-v2-1-2/*.patch "$OUT"/a-two-plus-one/kernel-patch-3/*.patch "$OUT"/a-two-plus-one/bluez-1/*.patch "$OUT"/a-two-plus-one/bluez-2/*.patch || exit 1
find "$OUT" -type f -name "*.patch" -exec sed -i -E 's/^Notes \(layout-a[0-9]\):$/Notes:/' {} + || exit 1
find "$OUT" -type f

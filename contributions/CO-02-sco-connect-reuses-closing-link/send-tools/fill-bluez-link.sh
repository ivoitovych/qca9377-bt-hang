#!/bin/bash
# fill-bluez-link.sh <package send dir> <Message-ID of the sent kernel cover letter>
# Run AFTER the kernel series is sent and BEFORE the BlueZ mail is: puts the lore link of the
# kernel series in place of @KERNEL_SERIES_LINK@ in the package's BlueZ mail (below ---, not part
# of the commit). The Message-ID is the one git send-email printed for the cover letter
# ([PATCH 0/3]); with or without the angle brackets. It must be the cover's: "-1-" before the
# address, and the author's address. Refuses a package without exactly one BlueZ mail, and a mail
# without exactly one placeholder. Whether the ID is THE cover that was sent is not something this
# script can know: open the printed link and see the series there.
set -u
shopt -s nullglob
OUT=${1:?usage: fill-bluez-link.sh <package send dir> <cover Message-ID>}
ID=${2:?usage: fill-bluez-link.sh <package send dir> <cover Message-ID>}
(( $# == 2 )) || { echo "usage: fill-bluez-link.sh <package send dir> <cover Message-ID>"; exit 2; }
ID=${ID#<}; ID=${ID%>}
AUTHOR=yaroslav.voytovych@gmail.com
[[ "$ID" =~ ^[0-9]{14}\.[0-9]+-1-(.+)$ && "${BASH_REMATCH[1]}" == "$AUTHOR" ]] || {
	echo "refusing: '$ID' is not a cover letter Message-ID of this author (expected <date>.<n>-1- then $AUTHOR)"; exit 2; }
F=("$OUT"/bluez/*.patch)
(( ${#F[@]} == 1 )) || { echo "refusing: $OUT/bluez must hold exactly one .patch file (found ${#F[@]})"; exit 2; }
M=${F[0]}
n=$(grep -c "@KERNEL_SERIES_LINK@" "$M"); rc=$?
(( rc <= 1 )) || { echo "refusing: cannot read $M"; exit 2; }
[[ "$n" == 1 ]] || { echo "refusing: $M has $n placeholders, expected 1"; exit 2; }
LINK="https://lore.kernel.org/linux-bluetooth/$ID/"
python3 -I -c 'import sys; p, l = sys.argv[1], sys.argv[2]; t = open(p).read(); open(p, "w").write(t.replace("@KERNEL_SERIES_LINK@", l, 1))' "$M" "$LINK" || exit 1
grep -n -B3 -A2 -F "$LINK" "$M"
echo "filled. Open $LINK : it must show \"[PATCH 0/3] Bluetooth: hci_conn: fix SCO connection reuse\""
echo "and its three patches. Then commit the filled mail before send.sh bluez --check."

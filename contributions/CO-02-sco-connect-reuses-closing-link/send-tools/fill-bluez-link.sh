#!/bin/bash
# fill-bluez-link.sh <package send dir> <Message-ID of the sent kernel cover letter>
# Run AFTER the kernel series is sent and BEFORE the BlueZ mail is: puts the lore link of the
# kernel series in place of @KERNEL_SERIES_LINK@ in the package's BlueZ mail (below ---, not part
# of the commit). The Message-ID is the one git send-email printed for the cover letter
# ([PATCH 0/3]); with or without the angle brackets. It must be the cover's: "-1-" before the
# address, and the author's address. Refuses a mail without exactly one placeholder.
set -u
OUT=${1:?usage: fill-bluez-link.sh <package send dir> <cover Message-ID>}
ID=${2:?usage: fill-bluez-link.sh <package send dir> <cover Message-ID>}
ID=${ID#<}; ID=${ID%>}
AUTHOR=yaroslav.voytovych@gmail.com
[[ "$ID" =~ ^[0-9]{14}\.[0-9]+-1-(.+)$ && "${BASH_REMATCH[1]}" == "$AUTHOR" ]] || {
	echo "refusing: '$ID' is not a cover letter Message-ID of this author (expected <date>.<n>-1- then $AUTHOR)"; exit 2; }
M=$(ls "$OUT"/bluez/0001-*.patch) || exit 2
n=$(grep -c "@KERNEL_SERIES_LINK@" "$M")
[[ "$n" == 1 ]] || { echo "refusing: $M has $n placeholders, expected 1"; exit 2; }
LINK="https://lore.kernel.org/linux-bluetooth/$ID/"
python3 -I -c 'import sys; p, l = sys.argv[1], sys.argv[2]; t = open(p).read(); open(p, "w").write(t.replace("@KERNEL_SERIES_LINK@", l, 1))' "$M" "$LINK" || exit 1
grep -n -B3 -A2 -F "$LINK" "$M"
echo "filled. Check the link opens the kernel series on lore before sending the BlueZ mail."

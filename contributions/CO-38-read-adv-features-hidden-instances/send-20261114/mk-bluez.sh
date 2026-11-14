#!/bin/bash
# mk-bluez.sh <base-ref> <outdir> - apply the three old CO-38 BlueZ patches on <base-ref> in the bluez
# clone (branch co38-bluez), regenerate with format-patch (no cover; the old cover text is carried over
# by mk-bluez-cover.py), report.
set -eu
W=/root/exp/agent-work/lane3-mgmt-20261114
OLD=/root/exp/qca9377-bt-hang/contributions/CO-38-read-adv-features-hidden-instances/send-20261102/bluez
B=$W/bluez
IN=$W/CO-38/bluez-in
OUT="$2"
mkdir -p "$IN" "$OUT"
for n in 0001-mgmt-tester-Add-extended-advertising-timeout-tests 0002-mgmt-tester-Add-test-for-listing-a-remaining-instanc 0003-mesh-tester-Add-Mesh-Send-test-with-extended-adverti; do
	python3 -I "$W/subst-addr.py" in "$OLD/$n.patch" "$IN/$n.patch"
done
git -C "$B" checkout -q -B co38-bluez "$1"
git -C "$B" am --3way "$IN"/0001-*.patch "$IN"/0002-*.patch "$IN"/0003-*.patch
git -C "$B" log --oneline -n 4
git -C "$B" format-patch -3 --subject-prefix="PATCH BlueZ" --base="$1" -o "$OUT"

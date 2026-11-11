#!/bin/bash
# run-matrix.sh <kernel tag> <run number>
# Every scenario of usbip-bt-emu.py once, one guest each, via run-guest.sh.
set -u
w=/root/exp/agent-work/laptop-btusb-modules-20261111
tag=${1:?usage}
n=${2:?usage}
for sc in msbc-two-links-first msbc-two-links-second cvsd-two-links-first msbc-single-race cvsd-single-race; do
	echo "== $tag $sc #$n"
	"$w/scripts/run-guest.sh" "$tag" "$sc" "$n"
done

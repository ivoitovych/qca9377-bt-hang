#!/bin/bash
# mk-kernel-patch.sh <tree> <branch> <base-ref> <outdir>
# Applies the old CO-38 diff on <base-ref>, commits with the message file and a placeholder
# author address (no Signed-off-by), format-patch --base.
set -eu
T="$1"; BR="$2"; BASE="$3"; OUT="$4"
OLD=/root/exp/qca9377-bt-hang/contributions/CO-38-read-adv-features-hidden-instances/send-20261102/0001-Bluetooth-MGMT-Fix-Read-Advertising-Features-hiding-.patch
W=/root/exp/agent-work/lane3-mgmt-20261114/CO-38
git -C "$T" checkout -q -B "$BR" "$BASE"
git -C "$T" apply "$OLD"
git -C "$T" add net/bluetooth/mgmt.c
git -C "$T" -c user.name="Iaroslav Voitovych" -c user.email="author@example.com" commit -q -F "$W/msg-kernel.txt" --author="Iaroslav Voitovych <author@example.com>"
mkdir -p "$OUT"
git -C "$T" format-patch -1 --base="$BASE" -o "$OUT"

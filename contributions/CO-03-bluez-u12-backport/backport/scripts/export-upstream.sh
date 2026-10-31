#!/bin/sh
# Export the upstream commits this backport draws on, as mails, from the
# read-only upstream checkout into upstream-patches/.
set -eu
up=/root/exp/qca9377-bt-hang/cache/bluez-upstream
out=/root/exp/agent-work/co03/upstream-patches
for c in a734b06059cb 0bed9886cff3 3d9900eb754d a14d59725ef3 664a5d3785a1 \
         aa118e965b02 47da1efdc584 87ad4c66b934; do
    git -C "$up" format-patch -1 --stdout "$c" > "$out/$c.patch"
    echo "$c $(git -C "$up" log -1 --format='%H %s' "$c")"
done

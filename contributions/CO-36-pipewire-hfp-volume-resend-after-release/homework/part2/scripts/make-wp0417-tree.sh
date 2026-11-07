#!/bin/sh
# T308: a second copy of PipeWire master 4cfc4711 (from the co36 copy,
# without build directories) whose subprojects/wireplumber is WirePlumber
# 0.4.17 (git archive of the tag in cache/wireplumber-upstream), the
# laptop's policy version.  PipeWire's own sources are unchanged.
set -eu
w=/root/exp/agent-work/co36
mkdir -p "$w/cache"
rsync -a \
    --exclude '/build-*' \
    --exclude '/subprojects/wireplumber' \
    --exclude '/test/bluezenv/test_co36_hfp_volume_resend.py' \
    "$w/pw/" "$w/pw-wp0417/"
git -C /root/exp/qca9377-bt-hang/cache/wireplumber-upstream archive \
    --format=tar --prefix=wireplumber/ -o "$w/cache/wireplumber-0.4.17.tar" 0.4.17
tar -xf "$w/cache/wireplumber-0.4.17.tar" -C "$w/pw-wp0417/subprojects"
grep -m1 "version" "$w/pw-wp0417/subprojects/wireplumber/meson.build"
echo done

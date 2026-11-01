#!/bin/sh
# CO-11a: btmon 5.72-0ubuntu5.8 three ways (stock; + fdbfe0018f6f; + both
# fdbfe0018f6f and dca0f10fd560) and the archive's own btmon, on the
# project's synthetic captures (tests/btmon/real/mkcap.py), at widths 10,
# 60, 80, 81, 82, 100, 250, 3000, 5000 and piped. All in containers.
# The upstream commits are exported unchanged with git format-patch.
set -u
R=/root/exp/agent-work/co03/review-20261101
W=$R/co11a
U=/root/exp/qca9377-bt-hang/cache/bluez-upstream
"$R/scripts/log.sh" "START co11a"
mkdir -p "$W/patches" "$W/caps"
git -C "$U" format-patch -1 --stdout fdbfe0018f6f > "$W/patches/0001-fdbfe0018f6f.patch"
git -C "$U" format-patch -1 --stdout dca0f10fd560 > "$W/patches/0002-dca0f10fd560.patch"
grep -m1 '^Subject' "$W/patches/0001-fdbfe0018f6f.patch"
grep -m1 '^Subject' "$W/patches/0002-dca0f10fd560.patch"
python3 -I /root/exp/qca9377-bt-hang/tests/btmon/real/mkcap.py "$W/caps"
sha256sum "$W/caps/"*
chmod +x "$W/inner-build.sh" "$W/inner-test.sh"
docker run --rm -v /root/exp/agent-work/co03/src/archive:/archive:ro -v "$W:/w" \
    co03-noble-build:1 /w/inner-build.sh > "$W/build.log" 2>&1
echo "build: container exit $?"
tail -12 "$W/build.log"
docker run --rm --network none -v "$W:/w" co03-noble-build:1 /w/inner-test.sh > "$W/test.log" 2>&1
echo "test: container exit $?"
"$R/scripts/log.sh" "END co11a"

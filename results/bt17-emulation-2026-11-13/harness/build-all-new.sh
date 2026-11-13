#!/bin/bash
# build-all-new.sh: b2 and ab2d (first attempt of b2/ab2d failed to compile and left no image;
# base-kml was built by the first version of this script); restores linux/ to its branch.
w=/root/exp/agent-work/bt17-emu-20261113
"$w/harness/build-rev.sh" b2 4f169ee7a kobj
"$w/harness/build-rev.sh" ab2d 6c7961a6b kobj
git -C "$w/linux" checkout -q bt17-final2
git -C "$w/linux" log -1 --oneline
echo ALL-BUILDS-DONE

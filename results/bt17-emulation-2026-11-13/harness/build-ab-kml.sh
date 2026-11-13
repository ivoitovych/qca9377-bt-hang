#!/bin/bash
# build-ab-kml.sh: ab-kml = the A+B kernel (HEAD a5f5a7335d06 as recorded in img/bzImage-ab.commit)
# with the kmemleak config of base-kml; restores linux/ to its branch.
w=/root/exp/agent-work/bt17-emu-20261113
"$w/harness/build-rev.sh" ab-kml a5f5a7335d06 kobj-kml
git -C "$w/linux" checkout -q bt17-final2
git -C "$w/linux" log -1 --oneline
echo AB-KML-DONE

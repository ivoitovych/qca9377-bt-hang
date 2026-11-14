#!/bin/bash
# ASan trees: master 20ffd285b ("master", built), master + the six patches ("series", co37 = 7450e626f45f),
# master + CO-37's three fixes + the standalone test ("seriesB", co37-indep = 6975d60bc21c).
# (A first version passed the branch name; in the clone it is origin/co37, so the build stopped before it started.)
W=/root/exp/agent-work/lane4-bluez-20261114/co37
S=$W/scripts/tree.sh
R=$W/bluez
[[ -e $W/runs/master/build.log ]] || $S build master "$R" 20ffd285b58facfd1f2478d159a5f941b09d5be1 || exit 1
$S build series "$R" 7450e626f45f1ba41c1adf75f978768e0a409f82 || exit 1
$S build seriesB "$R" 6975d60bc21c693a5c1f79295880e797afe377ed || exit 1
$S check master
$S check series
$S check seriesB

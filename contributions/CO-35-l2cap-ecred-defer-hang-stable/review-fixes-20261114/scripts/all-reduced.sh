#!/bin/bash
# All four lines, one after the other (one build, one guest at a time).
W=/root/exp/agent-work/lane4-bluez-20261114/stable-20261114
"$W/scripts/reduced-line.sh" v6.6.162 6.6.y 0 || exit 1
"$W/scripts/reduced-line.sh" v6.12.117 6.12.y 0 || exit 1
"$W/scripts/reduced-line.sh" v6.18.63 6.18.y 0 || exit 1
"$W/scripts/reduced-line.sh" v7.3.4 7.3.y 1 || exit 1
echo ALL-REDUCED-DONE >> "$W/progress.log"

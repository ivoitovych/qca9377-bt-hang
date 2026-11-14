#!/bin/bash
W=/root/exp/agent-work/lane5-status-stable-20261114/co35
$W/apply-check.sh v7.3.4 7.3.y
$W/apply-check.sh v6.18.63 6.18.y
$W/apply-check.sh v6.12.117 6.12.y
$W/apply-check.sh v6.6.162 6.6.y
echo ALL-APPLY-DONE >> $W/logs/apply-all.log

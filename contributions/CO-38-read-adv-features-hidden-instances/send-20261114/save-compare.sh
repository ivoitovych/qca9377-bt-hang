#!/bin/bash
# save-compare.sh - run compare-all.sh and keep the output in logs/compare-all.txt
W=/root/exp/agent-work/lane3-mgmt-20261114/CO-38
exec > "$W/logs/compare-all.txt" 2>&1
"$W/compare-all.sh"

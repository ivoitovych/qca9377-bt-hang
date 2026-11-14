#!/bin/bash
# The whole l2cap-tester of the reduced pair against the whole l2cap-tester of the full pair (lane 5's logs of
# the same tags, read only), case by case: scripts/compare-tester-verdicts.py. Output: logs/compare-<tag>.txt
R=/root/exp/qca9377-bt-hang
L5=/root/exp/agent-work/lane5-status-stable-20261114/co35/logs
W=/root/exp/agent-work/lane4-bluez-20261114/stable-20261114
cmpone() { # tag fullvariant redvariant
	echo "== $1: full pair ($2, lane 5) vs reduced pair ($3)"
	python3 -I "$R/scripts/compare-tester-verdicts.py" "$L5/full-$1-$2.log" "$W/logs/full-$1-$3.log"
	echo "exit $?"
}
{
	cmpone v6.6.162 pair red
	cmpone v6.12.117 pair red
	cmpone v6.18.63 pair red
	cmpone v7.3.4 pair-sci red-sci
} > "$W/logs/compare-reduced-vs-full.txt" 2>&1
cat "$W/logs/compare-reduced-vs-full.txt"

#!/bin/bash
# run-hang-probe.sh : which of {diag config, watcher child} makes the rare guest hang of kernel e123 go away?
W=/root/exp/agent-work/lane7-sco-20261114
R=$W/scripts/run-matrix.sh
$R probeA 6 e123d inc3 sco-tester
$R probeB 6 e123 inc4 sco-tester
echo "run-hang-probe done"

#!/bin/bash
# chain.sh : build the park kernels, then run the matrix
W=/root/exp/agent-work/lane7-sco-20261114
$W/scripts/build-park.sh || exit 1
$W/scripts/run-all-7.sh

#!/bin/sh
# SHA256SUMS of every raw output, variant, test file, harness copy and
# script of this work area (not the three PipeWire tree copies).
set -eu
W=/root/exp/agent-work/co36-v2v3-20261101
cd "$W"
find logs results variants extras unit ci scripts progress.log -type f -print0 \
	| sort -z | xargs -0 sha256sum > "$W/SHA256SUMS"
grep -c '' "$W/SHA256SUMS"
sha256sum "$W/SHA256SUMS"

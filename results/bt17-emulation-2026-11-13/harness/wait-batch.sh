#!/bin/bash
# wait-batch.sh <summary file> <last-line text>: returns when the batch has written its last line
f=${1:?usage}
until grep -q "${2:?usage}" "$f"; do sleep 10; done
cat "$f"

#!/bin/bash
# wait-batch.sh: returns when run-dropcmd-batch.sh has written its last line
f=/root/exp/agent-work/bt17-emu-20261113/logs/matrix-dropcmd-batch.txt
until grep -q "final h-recover-1 exit" "$f"; do sleep 10; done
cat "$f"

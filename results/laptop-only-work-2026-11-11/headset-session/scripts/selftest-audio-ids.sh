#!/bin/sh
# Self-test of kit/bin/audio-ids.py on a hand-made pw-dump (no live audio session is read).
top=/root/exp/agent-work/laptop-headset-session-20261111
python3 -I "$top/kit/bin/audio-ids.py" --json "$top/work/synthetic-pw-dump.json" > "$top/logs/selftest-audio-ids.txt" 2>&1
echo "exit $?" >> "$top/logs/selftest-audio-ids.txt"

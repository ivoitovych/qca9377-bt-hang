#!/bin/sh
# Self-test of kit/bin/after-session.py on archived 2026-10-24 journal text (read in place,
# never copied) with synthetic marks.  Output is masked by the tool itself.
top=/root/exp/agent-work/laptop-headset-session-20261111
inc=/root/exp/qca9377-bt-hang/archive/incidents/20261024-shure-mic-meter-and-vgm
"$top/scripts/log.sh" START selftest-after-session
python3 -I "$top/kit/bin/after-session.py" --marks-file "$top/work/test-marks.txt" \
  --from-file "$inc/journal-user-0755-0812.txt" --from-file "$inc/journal-bluetoothd-0755-0812.txt" \
  --window 600 --max-lines 12 > "$top/logs/selftest-after-session.txt" 2>&1
echo "exit $?" >> "$top/logs/selftest-after-session.txt"
"$top/scripts/log.sh" END selftest-after-session

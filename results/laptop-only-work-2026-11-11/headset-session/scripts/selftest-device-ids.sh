#!/bin/sh
# Self-test of kit/bin/device-ids-from-journal.py on archived journal text (read in place).
top=/root/exp/agent-work/laptop-headset-session-20261111
a=/root/exp/qca9377-bt-hang/archive/incidents
out=$top/logs/selftest-device-ids.txt
: > "$out"
for f in "$a/20261024-shure-mic-meter-and-vgm/journal-user-0755-0812.txt" \
         "$a/20261023-momentum-mic-gain-zero/journal-user-connect-0147.txt" \
         "$a/20261024-earbuds-discovery-and-sco-gap/journal-user-2200.txt"; do
  echo "== $(basename "$(dirname "$f")")" >> "$out"
  python3 -I "$top/kit/bin/device-ids-from-journal.py" --from-file "$f" >> "$out" 2>&1
done

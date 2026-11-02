#!/usr/bin/env python3
"""From a GST_DEBUG log with basesrc:5, list the source's slow pull requests (create calls)
and the request sizes, to see how the player asks for data.

  gstpull.py <gst.log> [threshold_seconds]
"""
import re
import sys
from collections import Counter

thr = float(sys.argv[2]) if len(sys.argv) > 2 else 0.05
rx = re.compile(r"^(\d+):(\d\d):(\d\d\.\d+)\s+\d+\s+(0x[0-9a-f]+)\s+\w+\s+basesrc\s+\S+:gst_base_src_get_range:<source> (.*)$")
pending = {}
sizes = Counter()
slow = []
n = 0
for line in open(sys.argv[1], errors="replace"):
    m = rx.match(line)
    if not m:
        continue
    h, mi, s, thread, msg = m.groups()
    t = int(h) * 3600 + int(mi) * 60 + float(s)
    c = re.match(r"calling create offset (\d+) length (\d+)", msg)
    if c:
        pending[thread] = (t, int(c.group(1)), int(c.group(2)))
        sizes[int(c.group(2))] += 1
        n += 1
    elif msg.startswith("buffer ok") and thread in pending:
        t0, off, ln = pending.pop(thread)
        if t - t0 >= thr:
            slow.append((t0, t - t0, off, ln))
print(f"{n} create calls; most common request sizes:", sizes.most_common(5))
print(f"== create calls taking >= {thr} s (log time, duration, offset in s of audio, length) ==")
for t0, d, off, ln in slow:
    print(f"t={t0:9.3f}  {d:6.3f} s  offset {off:>9} (~{off/176400:6.2f} s)  length {ln}")

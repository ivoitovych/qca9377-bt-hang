#!/usr/bin/env python3
"""journal-vs-links.py <journal.json> <sco-orphans output>

Places each kernel SCO error line on the link timeline of the same boot.

journal.json: `journalctl -o json --output-fields=_SOURCE_MONOTONIC_TIMESTAMP,
MESSAGE,__REALTIME_TIMESTAMP,__MONOTONIC_TIMESTAMP` lines. For a kernel line,
__REALTIME/__MONOTONIC are when journald received it and
_SOURCE_MONOTONIC_TIMESTAMP is the kernel's own printk time, so
  kernel time = __REALTIME - (__MONOTONIC - _SOURCE_MONOTONIC)
and the difference is journald's reception delay.

Per line: journal time, kernel time, delay, message, and where the kernel time
falls: "DC+x ms of handle h" (after a link's Disconnection Complete, nearest),
"during handle h (x s into it)", or "no link". Then totals per kind.
"""
import json
import re
import sys
from collections import Counter
from datetime import datetime

lines = []
with open(sys.argv[1]) as f:
    for raw in f:
        raw = raw.strip()
        if not raw.startswith("{"):
            continue
        e = json.loads(raw)
        rt = int(e["__REALTIME_TIMESTAMP"])
        mono = int(e["__MONOTONIC_TIMESTAMP"])
        src = int(e.get("_SOURCE_MONOTONIC_TIMESTAMP", mono))
        lines.append((rt - (mono - src), rt, mono - src, e["MESSAGE"]))

links = []
pat = re.compile(r"^LINK (\S+ \S+) h=(\d+) .*?held=([\d.]+)s")
with open(sys.argv[2]) as f:
    for raw in f:
        m = pat.match(raw)
        if not m:
            continue
        t0 = datetime.strptime(m.group(1), "%Y-%m-%d %H:%M:%S.%f").timestamp()
        held = float(m.group(3))
        links.append((t0, t0 + held, int(m.group(2))))


def where(t):
    for t0, t1, h in links:
        if t0 <= t <= t1:
            return f"during handle {h} ({t - t0:.1f} s in, {t1 - t:.3f} s before its DC)", "during"
    after = [(t - t1, h) for t0, t1, h in links if t >= t1]
    if after:
        d, h = min(after)
        if d < 1.0:
            return f"DC+{d * 1000:.1f} ms of handle {h}", "after-DC<1s"
        return f"{d:.1f} s after DC of handle {h}", "later"
    return "no link before", "none"


kinds = Counter()
delays = []
for kt, rt, delay, msg in sorted(lines):
    w, k = where(kt / 1e6)
    short = "corrupted" if "corrupted" in msg else ("unknown" if "unknown" in msg else msg)
    kinds[(short, k)] += 1
    delays.append(delay)
    print(f"{datetime.fromtimestamp(rt / 1e6).isoformat(sep=' ')}  kernel {datetime.fromtimestamp(kt / 1e6).isoformat(sep=' ')}"
          f"  delay {delay / 1e6:9.3f} s  {short:9}  {w}")
print()
for (s, k), n in sorted(kinds.items()):
    print(f"{s:9} {k:12} {n}")
late = [d for d in delays if d > 1_000_000]
print(f"lines {len(delays)}; journald reception delay > 1 s: {len(late)}; max {max(delays) / 1e6:.3f} s")

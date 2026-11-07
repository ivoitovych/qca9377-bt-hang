#!/usr/bin/env python3
"""corrupted-context.py <boot id> [<message regex>]

For every kernel error line of the boot matching the regex (default
"corrupted SCO packet"), reads the kernel's own debug lines of the 3 s before
and 0.5 s after it (dynamic debug of hci_conn.c, hci_event.c and btusb is on
on the laptop) and orders them by the kernel's printk time
(_SOURCE_MONOTONIC_TIMESTAMP), then classifies the line:

  teardown   after "hci0 hcon <p> handle N" (hci_conn_del() entry) and before
             the next "hci0 evt 6" (btusb_notify(HCI_NOTIFY_DISABLE_SCO));
  after-evt6 after the DISABLE notification (btusb_work() not yet done);
  mid-link   anything else (a link up, no teardown in progress).

Prints one line per error line with the markers' kernel times relative to it.
Reads the system journal only; prints no device addresses.
"""
import json
import re
import subprocess
import sys
from datetime import datetime, timedelta

boot = sys.argv[1]
rx = sys.argv[2] if len(sys.argv) > 2 else "corrupted SCO packet"


def jread(extra):
    cmd = ["journalctl", "-k", "--no-pager", "-o", "json", "-b", boot,
           "--output-fields=_SOURCE_MONOTONIC_TIMESTAMP,MESSAGE,__REALTIME_TIMESTAMP,__MONOTONIC_TIMESTAMP"] + extra
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    res = []
    for raw in out.splitlines():
        if raw.startswith("{"):
            e = json.loads(raw)
            msg = e.get("MESSAGE")
            if isinstance(msg, list):
                continue
            res.append((int(e.get("_SOURCE_MONOTONIC_TIMESTAMP", e["__MONOTONIC_TIMESTAMP"])),
                        int(e["__REALTIME_TIMESTAMP"]), msg))
    return res


hits = jread(["-p", "err", "--grep", rx])
marker = re.compile(r"^hci0 hcon \S+ handle (\d+)$|^hci0 evt [56]$|^hci0: handle 0x[0-9a-f]+ reason|^opcode 0x0406 status|corrupted SCO|unknown connection handle|^Looking for Alt no :6$")
seen = set()
counts = {}
for src, rt, msg in hits:
    if src in seen:
        continue
    t = datetime.fromtimestamp(rt / 1e6)
    since = (t - timedelta(seconds=3)).strftime("%Y-%m-%d %H:%M:%S.%f")
    until = (t + timedelta(seconds=0.5)).strftime("%Y-%m-%d %H:%M:%S.%f")
    ctx = sorted(x for x in jread(["--since", since, "--until", until]) if marker.search(x[2]))
    last_del = last_evt5 = last_disc = None
    nxt6 = None
    for s, _r, m in ctx:
        if s < src:
            if m.startswith("hci0 hcon"):
                last_del = (s, m)
            elif m == "hci0 evt 6":
                last_del = None if last_del and last_del[0] < s else last_del
                last_evt6 = s
            elif m == "hci0 evt 5":
                last_evt5 = s
            elif "reason" in m:
                last_disc = s
        elif s > src and m == "hci0 evt 6" and nxt6 is None:
            nxt6 = s
    prev6 = max([s for s, _r, m in ctx if m == "hci0 evt 6" and s < src], default=None)
    if last_del and nxt6 and (prev6 is None or prev6 < last_del[0]):
        kind = "teardown"
    elif prev6 and (last_evt5 is None or prev6 > last_evt5) and src - prev6 < 200_000:
        kind = "after-evt6"
    else:
        kind = "mid-link"
    counts[kind] = counts.get(kind, 0) + 1

    def rel(x):
        return f"{(x - src) / 1000:+.1f}ms" if x else "-"
    same = [s for s, _r, m in hits if abs(s - src) < 50_000]
    seen.update(same)
    print(f"{t.isoformat(sep=' ')} x{len(same)} {kind:10} "
          f"Disconnect-cmd {rel(last_disc)} conn_del {rel(last_del[0]) if last_del else '-'}"
          f" ({last_del[1].split()[-1] if last_del else '-'}) evt6-next {rel(nxt6)} evt5-prev {rel(last_evt5)}")
print(counts)

#!/usr/bin/env python3
"""late-vgm-scan.py: how often PipeWire's delayed HFP volume resend reaches the headset after
the hands-free audio link was released. Read-only; reads the journal.

PipeWire's HFP gateway sends +VGS/+VGM when a hands-free (SCO) link is ready and again 1.5 s
later (sco_ready() -> rfcomm_ag_sync_volume(..., true)). With the dummy call enabled, it sends
+CIEV: 2,1 when the link is acquired and +CIEV: 2,0 when it is released. WirePlumber logs every
line it sends as "RFCOMM >> <line>".

For each link (+CIEV: 2,1 ... +CIEV: 2,0) the script prints the link's start, its release, the
volume sends that belong to it, and whether a send came after the release (before the next link).

    late-vgm-scan.py [journalctl selection args, default: all boots]
"""
import json
import subprocess
import sys
from datetime import datetime

args = sys.argv[1:]
cmd = ["journalctl", "--no-pager", "-o", "json", "_COMM=wireplumber",
       "--grep", r"RFCOMM >> \+(CIEV: 2,[01]|VGM: |VGS: )"] + args
out = subprocess.run(cmd, capture_output=True, text=True)
if out.returncode not in (0, 1):
    sys.exit("journalctl failed: " + out.stderr.strip())

events = []
for line in out.stdout.splitlines():
    if not line.strip():
        continue
    e = json.loads(line)
    msg = e.get("MESSAGE")
    if isinstance(msg, list):
        msg = bytes(msg).decode("utf-8", "replace")
    t = int(e["__REALTIME_TIMESTAMP"]) / 1e6
    events.append((e["_BOOT_ID"], t, msg.split("RFCOMM >> ", 1)[1].strip()))


def ts(t):
    return datetime.fromtimestamp(t).strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]


links = []   # dicts: boot, start, end, sends [(t, text)]
cur = None
for boot, t, text in events:
    if cur is not None and cur["boot"] != boot:
        links.append(cur)
        cur = None
    if text == "+CIEV: 2,1":
        if cur is not None:
            links.append(cur)
        cur = {"boot": boot, "start": t, "end": None, "sends": []}
    elif text == "+CIEV: 2,0":
        if cur is not None and cur["end"] is None:
            cur["end"] = t
    elif cur is not None:
        cur["sends"].append((t, text))
if cur is not None:
    links.append(cur)

def resend(k):
    """The delayed resend: the first +VGM after the link's first one, 1.45-1.55 s later."""
    vgm = [t for t, text in k["sends"] if text.startswith("+VGM")]
    if len(vgm) < 2:
        return None
    for t in vgm[1:]:
        if 1.45 <= t - vgm[0] <= 1.55:
            return vgm[0], t
    return None


short = late = 0
print("only links released within 3 s of their +CIEV: 2,1 (all links are counted below)")
print("link start (local)        released after  first +VGM  resend      resend vs release")
for k in links:
    r = resend(k)
    if k["end"] is None or k["end"] - k["start"] > 3:
        continue
    short += 1
    if r is None:
        print("%s  %.3f s         (no resend pair)" % (ts(k["start"]), k["end"] - k["start"]))
        continue
    d = r[1] - k["end"]
    late += d > 0
    print("%s  %.3f s         %+.3f s    %+.3f s    %s" % (
        ts(k["start"]), k["end"] - k["start"], r[0] - k["start"], r[1] - k["start"],
        "AFTER by %.3f s" % d if d > 0 else "before by %.3f s" % -d))
print("links %d; released within 3 s: %d; resend sent after the release: %d" % (len(links), short, late))

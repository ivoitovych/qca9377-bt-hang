#!/usr/bin/env python3
"""boot-scan.py <outdir> <source>...  (read-only)

A source is a journal export (.export.zst) or the text "live:<boot id>" (journalctl -o export).
For every boot id found it writes <outdir>/scan-<bootid8>-<source tag>.json with: first and last
entry times, kernel version, the controller start-up lines (kept with monotonic time), shutdown,
suspend and trial-label lines, the last six messages.  Nothing is sent to any device.
"""
import json
import re
import subprocess
import sys
from collections import deque
from datetime import datetime
from multiprocessing import Pool

PAT = re.compile(rb"""(Linux version |using rampatch|QCA: patch rome|using NVM|"""
                 rb"""usb 3-3: USB disconnect|"""
                 rb"""Opcode 0x[0-9a-fA-F]+ failed|unexpected cc|"""
                 rb"""prev_shutdown|Trial (E1|E3|stock)|autostart|Controllers: 0)""")
SUSP = re.compile(rb"(PM: suspend (entry|exit)|PM: hibernation|Reached target Sleep|systemd-sleep)")
END = re.compile(rb"(The system will (power off|reboot|halt)|Reached target (Power-Off|Reboot|System Power Off|Shutdown|Final)|"
                 rb"Journal stopped|systemd-shutdown|Shutting down|Powering off|Rebooting|Reached target .*Power|"
                 rb"Starting .*(Power-Off|Reboot)|Stopped target)")
# only within the first 900 s of kernel time
PAT_EARLY = re.compile(rb"""(hci\d: QCA|QCA .*[Vv]ersion|usb 3-3: (new|New USB|Product|Manufacturer|.*idVendor)|"""
                       rb"""Bluetooth: hci\d|btusb|Bluetooth: |Bluetooth management interface|"""
                       rb"""Starting bluetooth|Started bluetooth)""")
CAP = 400
LASTN = 6


def local(us):
    return datetime.fromtimestamp(us / 1e6).strftime("%Y-%m-%d %H:%M:%S")


def scan(src):
    if src.startswith("live:"):
        cmd = ["journalctl", "-b", src[5:], "--no-pager", "-o", "export"]
        tag = "live"
    else:
        cmd = ["zstd", "-dcq", src]
        tag = "export"
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, bufsize=1 << 20)
    boots = {}
    ts = mono = 0
    bid = b""
    for line in p.stdout:
        if line.startswith(b"__REALTIME_TIMESTAMP="):
            ts = int(line[21:])
        elif line.startswith(b"__MONOTONIC_TIMESTAMP="):
            mono = int(line[22:])
        elif line.startswith(b"_BOOT_ID="):
            bid = line[9:].strip().decode()
            b = boots.get(bid)
            if b is None:
                b = boots[bid] = {"boot_id": bid, "src": src, "first_ts": ts, "first_mono": mono, "n": 0,
                                  "hits": [], "last": deque(maxlen=LASTN), "last_ts": ts}
            b["n"] += 1
            b["last_ts"] = ts
            b["last_mono"] = mono
        elif line.startswith(b"MESSAGE="):
            b = boots.get(bid)
            if b is None:
                continue
            b["last"].append((ts, line[8:200].decode(errors="replace").rstrip()))
            if SUSP.search(line):
                b["susp"] = b.get("susp", 0) + 1
                if b["susp"] <= 5:
                    b["hits"].append((ts, mono, line[8:400].decode(errors="replace").rstrip()))
                else:
                    b["susp_tail"] = (ts, mono, line[8:200].decode(errors="replace").rstrip())
            elif END.search(line):
                b.setdefault("end", deque(maxlen=14)).append((ts, mono, line[8:300].decode(errors="replace").rstrip()))
            elif b.setdefault("nh", 0) < CAP and (PAT.search(line) or (mono < 900000000 and PAT_EARLY.search(line))):
                b["nh"] += 1
                b["hits"].append((ts, mono, line[8:400].decode(errors="replace").rstrip()))
    p.wait()
    out = []
    for b in boots.values():
        b["last"] = list(b["last"])
        b["end"] = list(b.get("end", []))
        out.append(b)
    return src, tag, out


def main(argv):
    import glob
    outdir = argv[0]
    srcs = []
    for a in argv[1:]:
        srcs += sorted(glob.glob(a[5:])) if a.startswith("glob:") else [a]
    with Pool(10) as pool:
        for src, tag, boots in pool.imap_unordered(scan, srcs):
            for b in boots:
                name = f"{outdir}/scan-{b['boot_id'][:8]}-{tag}.json"
                with open(name, "w") as f:
                    json.dump(b, f)
            print(src, [(b["boot_id"][:8], local(b["first_ts"]), local(b["last_ts"]), b["n"]) for b in boots], flush=True)


if __name__ == "__main__":
    main(sys.argv[1:])

#!/usr/bin/env python3
"""List btusb runtime suspend/resume cycles from a kernel log with btusb debug on.

Usage: suspend-cycles.py <kernel-log.txt>   (journalctl -k -o short-precise text)

btusb_suspend(), btusb_resume() and btusb_disconnect() print "intf <ptr>" once
per interface (btusb.c, BT_DBG("intf %p", intf)). The controller has two
interfaces: 0 (HCI events/ACL, the primary) and 1 (isochronous, SCO).

- Lines less than 10 ms apart form one group.
- The USB core suspends a device's interfaces from the highest number down and
  resumes them from 0 up (drivers/usb/core/driver.c, usb_suspend_both() and
  usb_resume_both()). So a two-interface group ending with the primary is a
  device suspend, one starting with it is a device resume.
- The primary is taken as the pointer that ends the first two-interface group:
  the first event after bring-up is a suspend (checked by hand for the boots
  used; in the failing boot it is also the pointer btusb_disconnect() prints
  first, right before the HCI device is unregistered).
- A one-line group is interface 1 alone (its own autopm get/put around SCO),
  which does not suspend or resume the device, or a disconnect.
Prints each group, each device-level suspend's length, and a summary.
"""
import re, sys
from datetime import datetime

LINE = re.compile(r"^(\w{3} +\d+ [\d:.]+) \S+ kernel: (.*)$")
INTF = re.compile(r"^intf (?:0x)?([0-9a-f]+)$")

def ts(s):
    return datetime.strptime("2026 " + " ".join(s.split()), "%Y %b %d %H:%M:%S.%f")

lines = []
for raw in open(sys.argv[1], encoding="utf-8", errors="replace"):
    m = LINE.match(raw.rstrip("\n"))
    if not m:
        continue
    t, msg = ts(m.group(1)), m.group(2)
    if (i := INTF.match(msg)):
        lines.append((t, i.group(1)))
    elif "usb 3-3: USB disconnect" in msg:
        lines.append((t, "USB-DISCONNECT"))

groups = []
for t, p in lines:
    if groups and (t - groups[-1][-1][0]).total_seconds() < 0.010:
        groups[-1].append((t, p))
    else:
        groups.append([(t, p)])

primary = next((g[-1][1] for g in groups
                if len(g) == 2 and g[0][1] != g[1][1] and "USB-DISCONNECT" not in (g[0][1], g[1][1])), None)

suspended_at, durations = None, []
for g in groups:
    ptrs = [p for _, p in g]
    t0 = g[0][0]
    if len(g) == 2 and ptrs[0] != ptrs[1] and primary in ptrs and "USB-DISCONNECT" not in ptrs:
        if ptrs[-1] == primary:
            what = "device suspend"
            suspended_at = t0
        else:
            what = "device resume"
            if suspended_at:
                d = (t0 - suspended_at).total_seconds()
                durations.append(d)
                what += f"  (was suspended {d:.3f} s)"
                suspended_at = None
    else:
        what = "other: " + " ".join("primary" if p == primary else p for p in ptrs)
    print(t0.strftime("%H:%M:%S.%f"), what)

if suspended_at:
    print(f"OPEN: device suspended since {suspended_at.strftime('%H:%M:%S.%f')}, no device resume follows")
print(f"primary interface {primary}; completed device suspend/resume cycles {len(durations)}; "
      f"longest suspend {max(durations, default=0):.3f} s")

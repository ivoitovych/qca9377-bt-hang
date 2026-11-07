#!/usr/bin/python3 -I
"""From fetched Launchpad bugs (launchpad-bug-fetch.py output), extract per
bug: the USB IDs of Bluetooth-looking devices in lsusb attachments and the
description, the QCA PCI Wi-Fi chips, and QCA Bluetooth lines from dmesg
(rampatch/nvm loads, 'patch rome', opcode 0x2005, command timeouts).

Usage: launchpad-extract.py <launchpad dir> <out.tsv>
No personal data is written: only IDs, chip names, and the matching kernel
message text with timestamps stripped.
"""
import glob
import json
import os
import re
import sys

LP, OUT = sys.argv[1], sys.argv[2]
QCA_WIFI = {"168c:003e": "QCA6174", "168c:0042": "QCA9377", "168c:0036": "QCA9565",
            "168c:0034": "AR9462", "168c:0032": "AR9485", "168c:002b": "AR9285"}
LSUSB_LINE = re.compile(r"ID ([0-9a-fA-F]{4}):([0-9a-fA-F]{4})\s+(.*)")
BT_NAME = re.compile(r"bluetooth|atheros|qualcomm|qca|ar30|bt\b", re.I)
DMESG_KEYS = re.compile(
    r"(QCA: patch rome[^\n]*|rampatch[^\n]*|nvm_usb[^\n]*|don't support firmware rome[^\n]*|"
    r"unexpected event for opcode 0x2005[^\n]*|hci\d: command 0x[0-9a-f]{4} tx timeout|"
    r"hci\d: Opcode 0x[0-9a-f]{4} failed: -110|"
    r"ath10k_pci [^:]+: qca\w+ hw[\d.]+ target[^\n]*)", re.I)
USB_NEW = re.compile(r"New USB device found, idVendor=([0-9a-f]{4}), idProduct=([0-9a-f]{4})")

rows = []
for d in sorted(glob.glob(os.path.join(LP, "bug-*"))):
    bug = d.rsplit("-", 1)[-1]
    try:
        meta = json.load(open(os.path.join(d, "bug.json")))
    except Exception:
        continue
    texts = [meta.get("description", "") or ""]
    names = []
    for f in sorted(glob.glob(os.path.join(d, "att-*"))):
        try:
            texts.append(open(f, encoding="utf-8", errors="replace").read())
            names.append(os.path.basename(f)[4:])
        except OSError:
            pass
    all_text = "\n".join(texts)
    bt_ids = set()
    for m in LSUSB_LINE.finditer(all_text):
        if BT_NAME.search(m.group(3)) and m.group(1).lower() not in ("1d6b",):
            bt_ids.add(f"{m.group(1).lower()}:{m.group(2).lower()} {m.group(3).strip()[:50]}")
    wifi = sorted({n for k, n in QCA_WIFI.items() if k in all_text.lower()})
    keys = set()
    for m in DMESG_KEYS.finditer(all_text):
        s = re.sub(r"\s+", " ", m.group(1)).strip()
        s = re.sub(r"[0-9a-f]{2}(:[0-9a-f]{2}){5}", "<addr>", s, flags=re.I)
        keys.add(s[:110])
    usb_new = sorted({f"{a}:{b}" for a, b in USB_NEW.findall(all_text)})
    rows.append([bug, meta.get("title", "")[:90], meta.get("date_created", "")[:10],
                 " | ".join(sorted(bt_ids)), "+".join(wifi),
                 " | ".join(sorted(keys))[:900], ",".join(usb_new)[:300],
                 ",".join(names)[:200]])
with open(OUT, "w") as f:
    f.write("bug\ttitle\tcreated\tlsusb_bt_like\tqca_wifi\tdmesg_qca_lines\t"
            "usb_new_ids\tattachments\n")
    for r in rows:
        f.write("\t".join(x.replace("\t", " ").replace("\n", " ") for x in r) + "\n")
print(f"{len(rows)} bugs", file=sys.stderr)

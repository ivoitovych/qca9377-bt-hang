#!/usr/bin/python3 -I
"""List patch mails on the linux-bluetooth archive whose subject names a USB
VID:PID of a QCA-related vendor, and say whether that ID is in btusb's tables
(btusb_main.c at a given file) or ath3k.c now.

Usage: lore-id-patches.py <lore.git> <btusb_main.c> <ath3k.c> <out.tsv>
"""
import re
import subprocess
import sys

LORE, BTUSB, ATH3K, OUT = sys.argv[1:5]
VENDORS = {"0cf3", "13d3", "0489", "04ca", "0930", "0b05", "105b", "413c",
           "04c5", "04f2", "03f0", "17aa", "1690", "0e8d", "10ab", "2c7c", "28de"}
ID_RE = re.compile(r"\b(?:0x)?([0-9a-fA-F]{4})\s*[:/]\s*(?:0x)?([0-9a-fA-F]{4})\b")
ID_RE2 = re.compile(r"\b0x([0-9a-fA-F]{4})\s*,\s*0x([0-9a-fA-F]{4})\b")


def table(path):
    txt = open(path, encoding="utf-8", errors="replace").read()
    out = {}
    for m in re.finditer(r"USB_DEVICE\(\s*0x([0-9a-fA-F]{4})\s*,\s*0x([0-9a-fA-F]{4})\s*\)"
                         r"(?:\s*,\s*\.driver_info\s*=\s*([A-Z0-9_|\s]+?)\s*\})?", txt, re.S):
        key = f"{m.group(1).lower()}:{m.group(2).lower()}"
        flags = " ".join((m.group(3) or "").split()) or "(no flags)"
        out.setdefault(key, flags)
    return out


bt = table(BTUSB)
ak = table(ATH3K)
log = subprocess.run(
    ["git", "-C", LORE, "log", "--format=%h%x09%aI%x09%s", "HEAD"],
    capture_output=True, text=True, check=True).stdout
rows = []
for line in log.splitlines():
    h, d, s = line.split("\t", 2)
    if not re.search(r"\[PATCH", s, re.I) or re.search(r"AUTOSEL|^Re:", s, re.I):
        continue
    if not re.search(r"btusb|bluetooth|ath3k", s, re.I):
        continue
    ids = {f"{a.lower()}:{b.lower()}" for a, b in ID_RE.findall(s)}
    ids |= {f"{a.lower()}:{b.lower()}" for a, b in ID_RE2.findall(s)}
    for i in sorted(ids):
        if i.split(":")[0] not in VENDORS:
            continue
        rows.append((i, d[:10], h, bt.get(i, "-"), ak.get(i, "-"), s))
rows.sort()
with open(OUT, "w") as f:
    f.write("id\tdate\tlore_commit\tbtusb_now\tath3k_now\tsubject\n")
    for r in rows:
        f.write("\t".join(r) + "\n")
absent = sorted({r[0] for r in rows if r[3] == "-" and r[4] == "-"})
print(f"{len(rows)} subject/ID rows; IDs in neither table: {' '.join(absent)}",
      file=sys.stderr)

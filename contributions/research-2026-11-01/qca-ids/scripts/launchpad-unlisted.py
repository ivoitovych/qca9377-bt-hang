#!/usr/bin/python3 -I
"""From launchpad-extract.tsv: for bugs whose attachments show QCA6174 or
QCA9377 Wi-Fi, list the USB IDs that are Bluetooth devices (per the lsusb
names in the bug, or per linuxhw-bt-ids.tsv) and say whether each is in the
btusb/ath3k tables.

Usage: launchpad-unlisted.py <launchpad-extract.tsv> <linuxhw-bt-ids.tsv> <btusb_main.c> <ath3k.c> <out.tsv>
"""
import re
import sys

LP, HW, BTUSB, ATH3K, OUT = sys.argv[1:6]


def table(path):
    txt = open(path, encoding="utf-8", errors="replace").read()
    return {f"{a.lower()}:{b.lower()}" for a, b in re.findall(
        r"USB_DEVICE\(\s*0x([0-9a-fA-F]{4})\s*,\s*0x([0-9a-fA-F]{4})\s*\)", txt)}


tab = table(BTUSB) | table(ATH3K)
bt_known = {l.split("\t")[0] for l in open(HW).read().splitlines()[1:]}
rows = []
for line in open(LP).read().splitlines()[1:]:
    f = line.split("\t")
    bug, title, created, bt_like, wifi, keys, usb_new = f[0], f[1], f[2], f[3], f[4], f[5], f[6]
    if not re.search(r"QCA6174|QCA9377", wifi):
        continue
    ids = set(re.findall(r"\b([0-9a-f]{4}:[0-9a-f]{4})\b", bt_like + " " + usb_new))
    bt_ids = sorted(i for i in ids if i in bt_known or i in bt_like)
    for i in bt_ids:
        rows.append((i, "yes" if i in tab else "NO", bug, created, wifi,
                     "patch" if "patch rome" in keys else ("0x2005" if "0x2005" in keys else "-"),
                     title[:70]))
with open(OUT, "w") as o:
    o.write("id\tin_table\tbug\tcreated\twifi\tdmesg\ttitle\n")
    for r in sorted(rows):
        o.write("\t".join(r) + "\n")
print(f"{len(rows)} rows; not in table: "
      f"{sorted({r[0] for r in rows if r[1] == 'NO'})}", file=sys.stderr)

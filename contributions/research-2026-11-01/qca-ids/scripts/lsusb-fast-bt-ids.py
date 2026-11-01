#!/usr/bin/python3 -I
"""Fast pass over linuxhw LsUSB: grep finds every device whose descriptor says
'bDeviceProtocol 1 Bluetooth' (class e0/01/01 at device level) and the 'Bus
... ID vvvv:pppp' header 9 lines above it. Aggregates per ID: probes, table
state in btusb/ath3k, bcdDevice. Then, for each ID with no btusb/ath3k entry,
reads the LsPCI file of every probe and counts the QCA Wi-Fi chips seen.

Usage: lsusb-fast-bt-ids.py <LsUSB> <LsPCI> <btusb_main.c> <ath3k.c> <out.tsv>
"""
import collections
import os
import re
import subprocess
import sys

LSUSB, LSPCI, BTUSB, ATH3K, OUT = sys.argv[1:6]
QCA_WIFI = {"168c:003e": "QCA6174", "168c:0042": "QCA9377", "168c:0036": "QCA9565",
            "168c:0034": "AR9462", "168c:0032": "AR9485", "168c:002b": "AR9285",
            "168c:0030": "AR93xx", "168c:0041": "QCA6164"}


def table(path):
    txt = open(path, encoding="utf-8", errors="replace").read()
    out = {}
    for m in re.finditer(r"USB_DEVICE\(\s*0x([0-9a-fA-F]{4})\s*,\s*0x([0-9a-fA-F]{4})\s*\)"
                         r"(?:\s*,\s*\.driver_info\s*=\s*([A-Z0-9_|\s]+?)\s*\})?", txt, re.S):
        key = f"{m.group(1).lower()}:{m.group(2).lower()}"
        out.setdefault(key, " ".join((m.group(3) or "").split()) or "(no flags)")
    return out


bt, ak = table(BTUSB), table(ATH3K)
p = subprocess.run(["grep", "-r", "-B9", "-A7", "bDeviceProtocol         1 Bluetooth", LSUSB],
                   capture_output=True, text=True, errors="replace")
per = collections.defaultdict(lambda: {"n": 0, "bcd": collections.Counter(),
                                       "name": collections.Counter(), "files": []})
cur_id = None
for line in p.stdout.splitlines():
    if line == "--":
        cur_id = None
        continue
    m = re.match(r"^(.*?)[-:]Bus \d+ Device \d+: ID ([0-9a-f]{4}:[0-9a-f]{4})\s*(.*)$", line)
    if m:
        cur_id = m.group(2)
        cur_file = m.group(1)
        per[cur_id]["n"] += 1
        per[cur_id]["name"][m.group(3).strip()[:60]] += 1
        per[cur_id]["files"].append(os.path.relpath(cur_file, LSUSB))
        continue
    if cur_id and "bcdDevice" in line:
        per[cur_id]["bcd"][line.split()[-1]] += 1
        cur_id = None

with open(OUT, "w") as f:
    f.write("id\tprobes\tbtusb_entry\tath3k_entry\tbcdDevice\tlsusb_name\t"
            "pci_qca_wifi_in_same_probe\tmodels_top6\n")
    for i, r in sorted(per.items(), key=lambda kv: -kv[1]["n"]):
        b, a = bt.get(i, "-"), ak.get(i, "-")
        chips = collections.Counter()
        models = collections.Counter()
        if b == "-" and a == "-":
            for rel in r["files"]:
                pp = os.path.join(LSPCI, rel)
                parts = rel.split("/")
                models["/".join(parts[1:4])] += 1
                if not os.path.isfile(pp):
                    chips["no-lspci"] += 1
                    continue
                t = open(pp, encoding="utf-8", errors="replace").read().lower()
                hit = [n for k, n in QCA_WIFI.items() if f"[{k}]" in t]
                for n in hit or ["no-qca-wifi"]:
                    chips[n] += 1
        f.write("\t".join([
            i, str(r["n"]), b, a,
            "; ".join(f"{k} {v}" for k, v in r["bcd"].most_common(3)),
            "; ".join(f"{k} {v}" for k, v in r["name"].most_common(2)),
            "; ".join(f"{k} {v}" for k, v in chips.most_common()),
            "; ".join(f"{k} {v}" for k, v in models.most_common(6)),
        ]) + "\n")
print(f"{len(per)} Bluetooth IDs, {sum(r['n'] for r in per.values())} device rows",
      file=sys.stderr)

#!/usr/bin/python3 -I
"""Summarise fetched linuxhw dmesg files per USB ID: logs fetched, logs that
show the ID enumerating, logs with a QCA-setup marker ('QCA: patch rome' or
the 'Enhanced Setup Synchronous Connection command is advertised, but not
supported' line, which btusb_setup_qca() causes by setting
HCI_QUIRK_BROKEN_ENHANCED_SETUP_SYNC_CONN), logs with 'unexpected event for
opcode 0x2005', and the ath10k chip line.

Usage: dmesg-evidence-table.py <out.tsv> <dir> [<dir> ...]
File names: <vid>-<pid>-<probe>.txt
"""
import collections
import glob
import os
import re
import sys

OUT, DIRS = sys.argv[1], sys.argv[2:]
agg = collections.defaultdict(lambda: collections.Counter())
chips = collections.defaultdict(set)
for d in DIRS:
    for f in glob.glob(os.path.join(d, "*.txt")):
        m = re.match(r"([0-9a-f]{4})-([0-9a-f]{4})-", os.path.basename(f))
        if not m:
            continue
        vid, pid = m.groups()
        cid = f"{vid}:{pid}"
        t = open(f, encoding="utf-8", errors="replace").read()
        a = agg[cid]
        a["logs"] += 1
        enum = f"idVendor={vid}, idProduct={pid}" in t
        a["enum"] += enum
        if enum:
            a["enum_marker"] += bool(re.search(
                r"QCA: patch rome|Enhanced Setup Synchronous Connection command is advertised", t))
        a["0x2005"] += "unexpected event for opcode 0x2005" in t
        for c in re.findall(r"ath10k_pci [^:]+: (qca\w+ hw[\d.]+)", t):
            chips[cid].add(c)
with open(OUT, "w") as o:
    o.write("id\tlogs\tlogs_with_enumeration\tof_those_with_qca_setup_marker\t"
            "logs_with_0x2005\tath10k_chip\n")
    for cid in sorted(agg):
        a = agg[cid]
        o.write(f"{cid}\t{a['logs']}\t{a['enum']}\t{a['enum_marker']}\t{a['0x2005']}\t"
                f"{','.join(sorted(chips[cid]))}\n")
print(open(OUT).read(), file=sys.stderr)

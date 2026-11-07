#!/usr/bin/python3 -I
"""Survey linuxhw LsUSB probe files (lsusb -v output) for USB Bluetooth
controllers, and pair each probe with the PCI Wi-Fi chip from the LsPCI
probe file at the same relative path (if that tree is given).

Usage: lsusb-qca-survey.py <LsUSB dir> <LsPCI dir or -> <btusb_main.c> <ath3k.c> <outdir>

Writes:
  <outdir>/bt-ids.tsv      one row per Bluetooth VID:PID: probes, table state,
                           names, bcdDevice values, isoc alt signature, the
                           PCI Wi-Fi chips seen with it and how often
  <outdir>/bt-probes.tsv   one row per (probe, Bluetooth device)
Only relative probe paths are written (type/vendor/model/... as published).
"""
import collections
import os
import re
import sys

LSUSB, LSPCI, BTUSB, ATH3K, OUT = sys.argv[1:6]
os.makedirs(OUT, exist_ok=True)

QCA_WIFI = {
    "168c:003e": "QCA6174",
    "168c:0042": "QCA9377",
    "168c:0036": "QCA9565/AR9565",
    "168c:0034": "AR9462",
    "168c:0032": "AR9485",
    "168c:0030": "AR93xx",
    "168c:002b": "AR9285",
    "168c:0041": "QCA6164",
    "168c:0046": "QCA9984",
    "168c:003c": "QCA988x",
    "17cb:1101": "QCA6390",
    "17cb:1103": "WCN6855/QCA206x",
    "17cb:1107": "WCN785x",
}


def table(path):
    txt = open(path, encoding="utf-8", errors="replace").read()
    out = {}
    for m in re.finditer(r"USB_DEVICE\(\s*0x([0-9a-fA-F]{4})\s*,\s*0x([0-9a-fA-F]{4})\s*\)"
                         r"(?:\s*,\s*\.driver_info\s*=\s*([A-Z0-9_|\s]+?)\s*\})?", txt, re.S):
        key = f"{m.group(1).lower()}:{m.group(2).lower()}"
        flags = " ".join((m.group(3) or "").split()) or "(no flags)"
        out.setdefault(key, flags)
    return out


bt_table = table(BTUSB)
ath3k_table = table(ATH3K)

HDR = re.compile(r"^Bus \d+ Device \d+: ID ([0-9a-f]{4}):([0-9a-f]{4})\s*(.*)$")


def parse_lsusb(text):
    """yield dicts per device block"""
    blocks = re.split(r"\n(?=Bus \d+ Device \d+: ID )", text)
    for b in blocks:
        lines = b.splitlines()
        if not lines:
            continue
        m = HDR.match(lines[0])
        if not m:
            continue
        dev = {"id": f"{m.group(1)}:{m.group(2)}", "name": m.group(3).strip()}
        bt_if = False
        ifnum = alt = None
        isoc = collections.defaultdict(set)
        cur_iface_bt = False
        prod = ""
        bcd = ""
        dclass = ""
        for ln in lines[1:]:
            s = ln.strip()
            if s.startswith("bcdDevice"):
                bcd = s.split()[-1]
            elif s.startswith("bDeviceClass"):
                dclass = s.split(None, 1)[1] if len(s.split()) > 1 else ""
            elif s.startswith("iProduct"):
                parts = s.split(None, 2)
                prod = parts[2] if len(parts) > 2 else ""
            elif s.startswith("bInterfaceNumber"):
                ifnum = s.split()[1]
            elif s.startswith("bAlternateSetting"):
                alt = s.split()[1]
            elif s.startswith("bInterfaceClass"):
                cur_iface_bt = s.split()[1] == "224"
            elif s.startswith("bInterfaceProtocol") and cur_iface_bt:
                if s.split()[1] == "1":
                    bt_if = True
            elif s.startswith("wMaxPacketSize") and cur_iface_bt and ifnum == "1":
                mm = re.search(r"(\d+) bytes", s)
                if mm:
                    isoc[alt].add(int(mm.group(1)))
        if not bt_if:
            continue
        sig = ",".join(f"{a}:{max(v)}" for a, v in sorted(isoc.items(),
                                                           key=lambda kv: int(kv[0])))
        dev.update(bcd=bcd, prod=prod, dclass=dclass, isoc=sig)
        yield dev


def pci_chips(relpath):
    if LSPCI == "-":
        return set()
    p = os.path.join(LSPCI, relpath)
    if not os.path.isfile(p):
        return None
    txt = open(p, encoding="utf-8", errors="replace").read().lower()
    found = set()
    for pid, name in QCA_WIFI.items():
        if f"[{pid}]" in txt or re.search(rf"\b{pid}\b", txt):
            found.add(name)
    return found


per_id = collections.defaultdict(lambda: {
    "probes": 0, "names": collections.Counter(), "prods": collections.Counter(),
    "bcd": collections.Counter(), "isoc": collections.Counter(),
    "chips": collections.Counter(), "no_pci": 0, "types": collections.Counter(),
    "models": collections.Counter()})
nfiles = 0
with open(os.path.join(OUT, "bt-probes.tsv"), "w") as fp:
    fp.write("id\tbcdDevice\tiProduct\tisoc\tpci_wifi\trelpath\n")
    for root, dirs, files in os.walk(LSUSB):
        if "/.git" in root or root.endswith(".git"):
            continue
        for fn in files:
            path = os.path.join(root, fn)
            rel = os.path.relpath(path, LSUSB)
            if rel.count("/") < 4:
                continue
            nfiles += 1
            try:
                text = open(path, encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            devs = list(parse_lsusb(text))
            if not devs:
                continue
            chips = pci_chips(rel)
            parts = rel.split("/")
            for d in devs:
                r = per_id[d["id"]]
                r["probes"] += 1
                r["names"][d["name"]] += 1
                r["prods"][d["prod"]] += 1
                r["bcd"][d["bcd"]] += 1
                r["isoc"][d["isoc"]] += 1
                r["types"][parts[0]] += 1
                r["models"]["/".join(parts[1:4])] += 1
                if chips is None:
                    r["no_pci"] += 1
                    cs = "?"
                else:
                    for c in chips:
                        r["chips"][c] += 1
                    cs = "+".join(sorted(chips)) or "none"
                fp.write(f"{d['id']}\t{d['bcd']}\t{d['prod']}\t{d['isoc']}\t{cs}\t{rel}\n")

with open(os.path.join(OUT, "bt-ids.tsv"), "w") as f:
    f.write("id\tprobes\tbtusb_entry\tath3k_entry\tpci_wifi_with_it\tno_lspci\t"
            "bcdDevice\tisoc_alt:maxps\tlsusb_names\tiProduct\ttypes\tmodels_top5\n")
    for i, r in sorted(per_id.items(), key=lambda kv: -kv[1]["probes"]):
        f.write("\t".join([
            i, str(r["probes"]), bt_table.get(i, "-"), ath3k_table.get(i, "-"),
            "; ".join(f"{k} {v}" for k, v in r["chips"].most_common()),
            str(r["no_pci"]),
            "; ".join(f"{k} {v}" for k, v in r["bcd"].most_common(4)),
            "; ".join(f"{k} {v}" for k, v in r["isoc"].most_common(3)),
            "; ".join(f"{k} {v}" for k, v in r["names"].most_common(3)),
            "; ".join(f"{k} {v}" for k, v in r["prods"].most_common(3)),
            "; ".join(f"{k} {v}" for k, v in r["types"].most_common()),
            "; ".join(f"{k} {v}" for k, v in r["models"].most_common(5)),
        ]) + "\n")
print(f"{nfiles} probe files, {len(per_id)} Bluetooth IDs", file=sys.stderr)

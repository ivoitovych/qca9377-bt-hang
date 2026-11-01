#!/usr/bin/python3 -I
"""For each candidate USB ID, pick up to N probes from the linuxhw LsUSB
tree (newest kernel first), fetch the same probe's dmesg from the linuxhw
Dmesg repository (raw.githubusercontent.com), and record the Bluetooth/QCA
evidence: USB enumeration of the ID, btusb registration, 'QCA: patch rome',
rampatch/nvm loads, 'unexpected event for opcode 0x2005', HCI timeouts,
the ath10k chip line. Only kernel text is kept; addresses are masked.

Usage: candidate-dmesg.py <LsUSB dir> <outdir> <N> <vid:pid> [<vid:pid> ...]
Writes <outdir>/<vid>-<pid>-<probe>.txt (raw dmesg) and <outdir>/summary.tsv
(appends).
"""
import os
import re
import subprocess
import sys
import time
import urllib.parse
import urllib.request

LSUSB, OUT, N = sys.argv[1], sys.argv[2], int(sys.argv[3])
IDS = sys.argv[4:]
UA = "qca9377-bt-hang/check"
os.makedirs(OUT, exist_ok=True)
KEYS = re.compile(
    r"(QCA: patch rome[^\n]*|using rampatch file[^\n]*|using NVM file[^\n]*|"
    r"don't support firmware rome[^\n]*|unexpected event for opcode 0x2005|"
    r"command 0x[0-9a-f]{4} tx timeout|corrupted SCO packet|"
    r"ath10k_pci [^:]+: qca\w+ hw[\d.]+|Bluetooth: hci0: [^\n]*(?:firmware|Firmware)[^\n]*)")


def kver(path):
    m = re.search(r"/(\d+)\.(\d+)\.(\d+)[^/]*/X86_64/", path)
    return tuple(int(x) for x in m.groups()) if m else (0, 0, 0)


summ = open(os.path.join(OUT, "summary.tsv"), "a")
for cid in IDS:
    vid, pid = cid.split(":")
    r = subprocess.run(["grep", "-r", "-l", f"ID {cid} ", LSUSB],
                       capture_output=True, text=True)
    paths = [os.path.relpath(p, LSUSB) for p in r.stdout.splitlines()]
    paths.sort(key=kver, reverse=True)
    # one probe per computer id (path element 4) where possible
    seen, pick = set(), []
    for p in paths:
        comp = p.split("/")[4] if p.count("/") >= 5 else p
        if comp in seen:
            continue
        seen.add(comp)
        pick.append(p)
    got = 0
    for p in pick:
        if got >= N:
            break
        url = ("https://raw.githubusercontent.com/linuxhw/Dmesg/main/"
               + urllib.parse.quote(p))
        try:
            data = urllib.request.urlopen(urllib.request.Request(
                url, headers={"User-Agent": UA}), timeout=60).read().decode(
                "utf-8", "replace")
        except Exception as e:
            summ.write(f"{cid}\t{p}\tFETCH-FAILED {e}\t\t\t\t\t\n")
            continue
        probe = p.rsplit("/", 1)[-1]
        with open(os.path.join(OUT, f"{vid}-{pid}-{probe}.txt"), "w") as f:
            f.write(data)
        enum = bool(re.search(rf"idVendor={vid}, idProduct={pid}", data))
        boot_ok = "] Linux version" in data or "Command line:" in data
        btusb = "registered new interface driver btusb" in data
        hits = sorted({re.sub(r"\s+", " ", m.group(1))[:90] for m in KEYS.finditer(data)})
        n2005 = data.count("unexpected event for opcode 0x2005")
        patch = any(h.startswith("QCA: patch rome") or "rampatch" in h for h in hits)
        summ.write("\t".join([
            cid, p, f"lines={data.count(chr(10))}", f"boot_start={'yes' if boot_ok else 'no'}",
            f"enum={'yes' if enum else 'no'}", f"btusb={'yes' if btusb else 'no'}",
            f"qca_patch={'yes' if patch else 'no'}", f"0x2005x{n2005}",
            " | ".join(h for h in hits if '0x2005' not in h)]) + "\n")
        summ.flush()
        got += 1
        time.sleep(0.5)
    print(f"{cid}: {len(paths)} probes, fetched {got}", file=sys.stderr)

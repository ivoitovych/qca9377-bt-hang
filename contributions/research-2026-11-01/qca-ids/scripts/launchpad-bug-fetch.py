#!/usr/bin/python3 -I
"""Fetch, read only and anonymously, each Launchpad bug's description and its
lsusb / lspci / dmesg attachments (apport names), into <outdir>/bug-<id>/.

Usage: launchpad-bug-fetch.py <outdir> <bug-id> [<bug-id> ...]
Files already present are not fetched again.
"""
import json
import os
import re
import sys
import time
import urllib.request

UA = "qca9377-bt-hang/check"
WANT = re.compile(r"(lsusb|lspci|dmesg|usb-devices)", re.I)


def get(url, binary=False):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=120) as r:
        data = r.read()
    return data if binary else data.decode("utf-8", "replace")


outdir = sys.argv[1]
bugs = sys.argv[2:]
if bugs and bugs[0] == "--from-summary":
    # every bug from summary.tsv except those found only by the broad
    # "13d3:" query whose title does not name Bluetooth
    bugs = []
    for line in open(bugs_src := sys.argv[3]).read().splitlines()[1:]:
        bug, st, created, tgt, qs, title = line.split("\t", 5)
        only_broad = qs.strip() == "13d3:"
        if only_broad and not re.search(r"bluetooth|bt\b|qca|atheros", title, re.I):
            continue
        bugs.append(bug)
    print(f"{len(bugs)} bugs selected", file=sys.stderr)
for bug in bugs:
    d = os.path.join(outdir, f"bug-{bug}")
    os.makedirs(d, exist_ok=True)
    desc = os.path.join(d, "bug.json")
    if not os.path.exists(desc):
        with open(desc, "w") as f:
            f.write(get(f"https://api.launchpad.net/1.0/bugs/{bug}"))
    att_index = os.path.join(d, "attachments.json")
    if not os.path.exists(att_index):
        with open(att_index, "w") as f:
            f.write(get(f"https://api.launchpad.net/1.0/bugs/{bug}/attachments?ws.size=200"))
    atts = json.load(open(att_index)).get("entries", [])
    n = 0
    for a in atts:
        title = a.get("title", "")
        if not WANT.search(title):
            continue
        safe = "".join(c if c.isalnum() or c in "._-" else "_" for c in title)[:80]
        path = os.path.join(d, "att-" + safe)
        if os.path.exists(path):
            continue
        try:
            data = get(a["data_link"], binary=True)
        except Exception as e:  # keep going; record the failure
            print(f"{bug}\t{title}\tFAILED {e}", file=sys.stderr)
            continue
        with open(path, "wb") as f:
            f.write(data[:5_000_000])
        n += 1
        time.sleep(0.3)
    print(f"{bug}\t{len(atts)} attachments, {n} fetched", file=sys.stderr)
    time.sleep(0.3)

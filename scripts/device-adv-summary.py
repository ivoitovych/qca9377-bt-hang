#!/usr/bin/env python3
"""Summarise a btmon decode (capture-window.sh output): for one address, every
advertising report or inquiry result with its time, kind and AD flags; plus,
in a quiet window, how many reports from OTHER addresses arrived (proof that
scanning was running while the address was silent).

usage: adv-summary.py <decode.txt> <address> <quiet-from HH:MM:SS> <quiet-to HH:MM:SS>
"""
import re
import sys

path, addr, qfrom, qto = sys.argv[1:5]
head = re.compile(r"^[<>@] .*(\d\d:\d\d:\d\d\.\d+)\s*$")

packets = []
cur = None
with open(path, errors="replace") as f:
    for line in f:
        m = head.match(line)
        if m:
            cur = {"time": m.group(1), "lines": [line.rstrip()]}
            packets.append(cur)
        elif cur is not None:
            cur["lines"].append(line.rstrip())

other_in_quiet = 0
for p in packets:
    text = "\n".join(p["lines"])
    kind = None
    if "LE Advertising Report" in text:
        et = re.search(r"Event type: (.*)", text)
        kind = "LE " + (et.group(1).split(" - ")[-1] if et else "?")
    elif "Extended Inquiry Result" in text:
        kind = "BR/EDR Extended Inquiry Result"
    elif "Inquiry Result" in text:
        kind = "BR/EDR Inquiry Result"
    if kind is None:
        continue
    a = re.search(r"Address: ([0-9A-F:]{17})", text)
    if not a:
        continue
    if a.group(1) == addr:
        fl = re.search(r"Flags: (0x[0-9a-f]+)", text)
        print(p["time"], kind, "flags", fl.group(1) if fl else "-")
    elif qfrom <= p["time"][:8] < qto:
        other_in_quiet += 1

# "from … to …", not "a-b": two times joined by a dash read as a MAC to the publish scan
print(f"reports from other addresses, from {qfrom} to {qto}: {other_in_quiet}")

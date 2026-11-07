#!/usr/bin/env python3
"""at-lines.py: compact list of HFP AT traffic from a capture-window.sh decode.

Usage: at-lines.py <decode.txt> [<ere>]

For each btmon packet block (header line "< ACL Data TX" / "> ACL Data RX" with the
time at its end) prints: time, direction (TX = laptop to headset, RX = headset to
laptop), handle, and the ASCII column of its hex lines joined (AT text), when the
joined text matches the optional regex (default: VGM|VGS|BRSF|BCS|BAC|CIEV). Addresses
never appear in this output (only handles and AT text). Read only.
"""
import re
import sys

HDR = re.compile(r"^([<>]) ACL Data (TX|RX): Handle (\d+).*?(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+)\s*$")
HEX = re.compile(r"^\s+((?:[0-9a-f]{2} )+)\s*(.*)$")


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    rx = re.compile(argv[1] if len(argv) > 1 else r"VGM|VGS|BRSF|BCS|BAC|CIEV")
    cur = None
    out = []

    def flush():
        if cur is None:
            return
        raw = bytes.fromhex("".join(cur["hex"]).replace(" ", ""))
        text = raw.decode("latin-1")
        m = re.findall(r"(AT\+[A-Z]+[=?][^\r\n]*|\+[A-Z]+: ?[^\r\n]*|AT\+[A-Z]+)", text)
        s = " | ".join(x.strip() for x in m)
        if s and rx.search(s):
            out.append(f"{cur['time']} {cur['dir']} h{cur['handle']} {s}")

    with open(argv[0], encoding="utf-8", errors="replace") as fh:
        for line in fh:
            h = HDR.match(line.rstrip("\n"))
            if h:
                flush()
                cur = {"dir": h.group(2), "handle": h.group(3), "time": h.group(4), "hex": []}
                continue
            if line.startswith(("<", ">", "@", "=")):
                flush()
                cur = None
                continue
            if cur is not None:
                x = HEX.match(line.rstrip("\n"))
                if x and not line.strip().startswith(("Address", "Control", "Length", "FCS", "Credits")):
                    cur["hex"].append(x.group(1))
    flush()
    for o in out:
        print(o)
    print(f"lines: {len(out)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

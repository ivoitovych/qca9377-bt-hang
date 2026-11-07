#!/usr/bin/env python3
# categories.py <full log> : non-passing cases of a tester run grouped by PHY / Timestamping / Ethtool / other
import re, sys
ANSI = re.compile(r"\x1b\[[0-9;]*m")
LINE = re.compile(r"^(.*?) - test (passed|failed|timed out)\s*$")
seen = {}
for l in open(sys.argv[1], errors="replace"):
    m = LINE.match(ANSI.sub("", l).rstrip("\r\n"))
    if m and m.group(2) != "passed":
        seen[m.group(1)] = m.group(2)
cat = {}
for k, v in seen.items():
    c = "PHY" if "PHY" in k else "Timestamping" if "Timestamping" in k else "Ethtool" if "Ethtool" in k else "other:" + v
    cat.setdefault(c, []).append(k)
for c, ks in sorted(cat.items()):
    print(c, len(ks), ks if c.startswith("other") else "")
print("total", len(seen))

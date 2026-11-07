#!/usr/bin/env python3
# compare.py <patched full log> <base log>... : per-case verdicts from tester output; every patched
# non-pass must be non-pass on base (base verdicts pooled over the given base logs; a pass in any
# base log counts as a pass).
import re, sys
ANSI = re.compile(r"\x1b\[[0-9;]*m")
LINE = re.compile(r"^(.*?) - test (passed|failed|timed out)\s*$")
def verdicts(path):
    d = {}
    for l in open(path, errors="replace"):
        l = ANSI.sub("", l).rstrip("\r\n")
        m = LINE.match(l)
        if m:
            d[m.group(1)] = m.group(2)
    return d
p = verdicts(sys.argv[1])
b = {}
for f in sys.argv[2:]:
    for k, v in verdicts(f).items():
        if v == "passed" or k not in b:
            b[k] = v
cnt = lambda d: {v: sum(1 for x in d.values() if x == v) for v in ("passed", "failed", "timed out")}
print("patched:", len(p), cnt(p))
print("base pooled:", len(b), cnt(b))
bad = [k for k, v in p.items() if v != "passed" and b.get(k) == "passed"]
nob = [k for k, v in p.items() if v != "passed" and k not in b]
both = [k for k, v in p.items() if v != "passed" and k in b and b[k] != "passed"]
print("patched non-pass that PASS on base (regressions):", len(bad), bad)
print("patched non-pass not run on base:", len(nob), nob)
print("patched non-pass also non-pass on base:", len(both))
other = [k for k, v in p.items() if v == "passed" and b.get(k) not in (None, "passed")]
print("passed patched, non-pass on base:", len(other), other)

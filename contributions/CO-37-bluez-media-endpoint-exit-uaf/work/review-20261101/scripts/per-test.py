#!/usr/bin/python3 -I
"""
per-test.py <run dir> <label> [<label>...]

For each <label>-<i>.debug.log in <run dir>: per test (from the
"==== <nodeid>: <stage> ====" markers), the call/teardown outcome and each
AddressSanitizer report raised by a bluetoothd while that test ran: the
host, the SUMMARY line, the use frames #0-#3 and the first "freed by"
frame below #0. Then a count per test and report across all runs.
"""

import collections
import re
import sys
from pathlib import Path

STAGE = re.compile(r"^==== (\S+): (setup|call|teardown)( (\w+))? ====$")
OUT = re.compile(r"OUT\s+(host\.\d+\.\d+\.bluetoothd) :  (.*)$")


def short(nodeid):
    m = re.search(r"::(\w+)\[[^\]]*?(?:vm\d+-)?([^\]]*)\]$", nodeid)
    if m:
        return f"{m.group(1)}[{m.group(2)}]"
    return nodeid.split("::")[-1]


def scan(path):
    tests = collections.OrderedDict()
    cur = None
    report = None
    in_freed = False
    for line in path.read_text(errors="replace").splitlines():
        m = STAGE.match(line)
        if m:
            cur = short(m.group(1))
            t = tests.setdefault(cur, {"outcome": {}, "reports": []})
            if m.group(4):
                t["outcome"][m.group(2)] = m.group(4)
            continue
        m = OUT.search(line)
        if not m or cur is None:
            continue
        host, text = m.group(1), m.group(2)
        if "ERROR: AddressSanitizer" in text:
            report = {"host": host, "frames": [], "freed": None, "summary": None}
            tests[cur]["reports"].append(report)
            in_freed = False
            continue
        if report is None or report["host"] != host:
            continue
        f = re.match(r"\s*#(\d+) 0x[0-9a-f]+ in (\S+) (\S+)", text)
        if text.startswith("freed by"):
            in_freed = True
        elif f and in_freed and f.group(1) != "0" and report["freed"] is None:
            report["freed"] = f"{f.group(2)} {f.group(3)}"
        elif f and not in_freed and int(f.group(1)) <= 3:
            report["frames"].append(f"{f.group(2)} {f.group(3)}")
        elif text.startswith("SUMMARY: AddressSanitizer"):
            report["summary"] = text
            report = None
    return tests


def main():
    args = sys.argv[1:]
    quiet = args[0] == "--totals"
    if quiet:
        args = args[1:]
        sys.stdout = open("/dev/null", "w")
        real = sys.__stdout__
    d = Path(args[0])
    totals = collections.Counter()
    runs = collections.Counter()
    for label in args[1:]:
        for log in sorted(
            d.glob(f"{label}-*.debug.log"),
            key=lambda p: int(re.search(r"-(\d+)\.debug\.log$", p.name).group(1)),
        ):
            print(f"== {log.name}")
            for name, t in scan(log).items():
                o = t["outcome"]
                print(
                    f"  {name}: call {o.get('call', '-')}, teardown "
                    f"{o.get('teardown', '-')}, reports {len(t['reports'])}"
                )
                runs[name] += 1
                if not t["reports"]:
                    totals[(name, f"no report, call {o.get('call', '-')}")] += 1
                for r in t["reports"]:
                    print(f"    {r['host']}: {r['summary']}")
                    print(f"      use: {' <- '.join(r['frames'])}")
                    print(f"      freed: {r['freed']}")
                    s = (r["summary"] or "?").split("AddressSanitizer: ")[-1]
                    totals[(name, f"{r['host'].split('.')[1]}: {s}")] += 1
    if quiet:
        sys.stdout = real
    print(f"== totals {d.name} {' '.join(args[1:])} (test | report | runs)")
    for (name, what), n in sorted(totals.items()):
        print(f"  {name} | {what} | {n} of {runs[name]}")


main()

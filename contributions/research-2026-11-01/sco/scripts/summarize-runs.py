#!/usr/bin/env python3
"""Summarise research-sco tester logs: per log the booted kernel, the Total line,
the verdicts of the cases both series add, and kernel report counts.

Usage: summarize-runs.py <log>...
"""
import os
import re
import sys

ANSI = re.compile(r"\x1b\[[0-9;]*m")
CASES = ["Close Before Complete", "Reconnect After Disconnect",
         "Reconnect During Disconnect Retry", "Reconnect During Disconnect",
         "Connect Twice", "Exp Close Pending", "Exp Poweroff Pending"]
REPORTS = {
    "KASAN": re.compile(r"BUG: KASAN"),
    "lockdep": re.compile(r"possible circular locking|inconsistent lock state|possible recursive locking|WARNING: suspicious RCU"),
    "WARNING": re.compile(r"WARNING: CPU: |------------\[ cut here \]"),
    "BUG/Oops": re.compile(r"BUG: |Oops|general protection fault|Kernel panic"),
    "sleep-in-atomic": re.compile(r"sleeping function called from invalid context"),
    "hung": re.compile(r"blocked for more than"),
}


def main(paths):
    out = None
    if paths[:1] == ["--out"]:
        out = open(paths[1], "x")
        paths = paths[2:]
        sys.stdout = out
    files = []
    for a in paths:
        if os.path.isdir(a):
            files += [os.path.join(a, n) for n in os.listdir(a) if n.startswith("run-") and n.endswith(".log")]
        else:
            files.append(a)
    for p in sorted(files):
        text = ANSI.sub("", open(p, errors="replace").read())
        ver = re.search(r"Linux version (\S+)", text)
        tot = re.findall(r"Total: .*", text)
        verdicts = []
        for line in text.splitlines():
            m = re.match(r"^(\S.*?)\s{2,}(Passed|Failed|Timed out|Not Run)\s+([\d.]+) seconds", line)
            if m and any(c in m.group(1) for c in CASES):
                verdicts.append(f"{m.group(1).strip()}={m.group(2)}")
            elif m and m.group(2) != "Passed":
                verdicts.append(f"OTHER {m.group(1).strip()}={m.group(2)}")
        reps = {k: len(r.findall(text)) for k, r in REPORTS.items()}
        reps = {k: v for k, v in reps.items() if v}
        print(f"{os.path.basename(p)}")
        print(f"   kernel {ver.group(1) if ver else 'MISSING'}; {tot[-1] if tot else 'NO TOTAL'}")
        for v in verdicts:
            print(f"   {v}")
        print(f"   reports: {reps if reps else 'none'}")


if __name__ == "__main__":
    main(sys.argv[1:])

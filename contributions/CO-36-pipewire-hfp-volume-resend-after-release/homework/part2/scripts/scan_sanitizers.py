#!/usr/bin/env python3
"""
T236: scan every log of agent-work/co36 for sanitizer reports and crash
markers, and list core files the VMs left in the trees.

Usage: python3 -I scan_sanitizers.py <out file> <log or dir>...
Reports, per file: line count, and every line matching a pattern (first
50 per pattern per file).
"""
import os
import re
import sys

PATTERNS = {
    "asan": re.compile(r"ERROR: AddressSanitizer|AddressSanitizer:"),
    "lsan": re.compile(r"LeakSanitizer"),
    "ubsan": re.compile(r"runtime error:|UndefinedBehaviorSanitizer"),
    "summary": re.compile(r"SUMMARY: (Address|Undefined|Leak)"),
    "terminated": re.compile(r"terminated by signal|process terminated|exited with code [1-9]"),
    # not "\.core\b": that matched every "pw.core" log topic (first scan)
    "coredump": re.compile(r"CoredumpWarning|core dumped|test-bluezenv-\S+\.core"),
}


def files(args):
    for a in args:
        if os.path.isdir(a):
            for name in sorted(os.listdir(a)):
                p = os.path.join(a, name)
                if os.path.isfile(p) and (name.endswith(".log") or name.endswith(".txt")):
                    yield p
        else:
            yield a


def main():
    out = open(sys.argv[1], "w")
    total = {k: 0 for k in PATTERNS}
    for path in files(sys.argv[2:]):
        hits = {k: [] for k in PATTERNS}
        n = 0
        with open(path, errors="replace") as f:
            for n, line in enumerate(f, 1):
                for k, pat in PATTERNS.items():
                    if pat.search(line):
                        hits[k].append(f"{n}: {line.rstrip()[:400]}")
        out.write(f"\n== {path} ({n} lines)\n")
        for k, lst in hits.items():
            total[k] += len(lst)
            out.write(f"  {k}: {len(lst)}\n")
            for h in lst[:50]:
                out.write(f"    {h}\n")
    out.write("\n== totals " + repr(total) + "\n")
    for tree in ("/root/exp/agent-work/co36/pw", "/root/exp/agent-work/co36/pw-wp0417"):
        cores = sorted(n for n in os.listdir(tree) if n.endswith(".core"))
        out.write(f"== core files in {tree}: {len(cores)}\n")
        for c in cores:
            st = os.stat(os.path.join(tree, c))
            out.write(f"    {c} {st.st_size}\n")
    out.close()


if __name__ == "__main__":
    main()

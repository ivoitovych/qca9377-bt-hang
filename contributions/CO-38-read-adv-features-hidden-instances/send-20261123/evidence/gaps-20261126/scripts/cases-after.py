#!/usr/bin/env python3
"""cases-after.py <complete tester log> <case name>

Print, one per line, the names of the cases that come after <case name> in the summary of a complete BlueZ tester
run (the block before "Total:"). Used to run, one by one, the cases a hang cut off on another kernel.
"""
import re
import sys

ANSI = re.compile(r"\x1b\[[0-9;]*m")
ROW = re.compile(r"^(.*?)\s+(Passed|Failed|Not Run|Timed out)\s+[0-9.]+ seconds\s*$")


def main():
    log, case = sys.argv[1], sys.argv[2]
    names = []
    with open(log, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = ANSI.sub("", line.rstrip("\n"))
            if line.startswith("Total:"):
                break
            m = ROW.match(line)
            if m:
                names.append(m.group(1))
    if case not in names:
        sys.exit(f"case not in the summary: {case}")
    for n in names[names.index(case) + 1:]:
        print(n)


if __name__ == "__main__":
    main()

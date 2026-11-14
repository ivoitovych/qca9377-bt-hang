#!/usr/bin/env python3
"""Check that the mail's indented log lines equal the given log lines verbatim.

Usage: excerpt-check.py <mail.txt> <log> <line>...
Compares, in order, every mail line starting with "  [" (indent removed)
with the log's line N after removing ANSI colour codes.
"""
import re
import sys

ANSI = re.compile(r"\x1b\[[0-9;]*m")


def main():
    mail, log, nums = sys.argv[1], sys.argv[2], [int(n) for n in sys.argv[3:]]
    mlines = [l[2:] for l in open(mail, encoding="utf-8").read().split("\n")
              if l.startswith("  [")]
    llines = open(log, encoding="utf-8", errors="replace").read().split("\n")
    ok = len(mlines) == len(nums)
    print("mail lines:", len(mlines), "requested:", len(nums))
    for m, n in zip(mlines, nums):
        want = ANSI.sub("", llines[n - 1])
        same = m == want
        ok &= same
        print("OK  " if same else "DIFF", n, m if same else (m, want))
    print("ALL VERBATIM" if ok else "MISMATCH")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()

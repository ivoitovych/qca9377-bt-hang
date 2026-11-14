#!/usr/bin/env python3
"""Print given lines of a log with ANSI colour codes removed.

Usage: excerpt.py <log> <line> [<line>...]
Output: "<line>: <text>" with the text otherwise byte-for-byte as in the log.
Use --bare to print the text only (for pasting into the mail).
"""
import re
import sys

ANSI = re.compile(r"\x1b\[[0-9;]*m")


def main():
    args = sys.argv[1:]
    bare = "--bare" in args
    args = [a for a in args if a != "--bare"]
    path, wanted = args[0], [int(n) for n in args[1:]]
    with open(path, encoding="utf-8", errors="replace") as f:
        lines = f.read().split("\n")
    for n in wanted:
        text = ANSI.sub("", lines[n - 1])
        print(text if bare else "%d: %s" % (n, text))


if __name__ == "__main__":
    main()

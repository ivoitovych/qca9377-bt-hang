#!/usr/bin/env python3
"""
grep-range.py <file> <first line> <last line> <regex>

Print the lines (with numbers) between first and last, inclusive, that
match the regex.
"""
import re
import sys

path, first, last, pattern = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
rx = re.compile(pattern)
with open(path, errors="replace") as f:
    for n, line in enumerate(f, 1):
        if n > last:
            break
        if n >= first and rx.search(line):
            print(f"{n}:{line.rstrip()}")

#!/usr/bin/env python3
"""Diff named C functions between two source files.
Usage: func-diff.py <file A> <file B> <function>...
A function is taken from its definition line (name followed by '(' at the
start of a line or after the return type) to the first line that is a lone
'}'."""
import difflib
import re
import sys


def extract(path, name):
    lines = open(path, encoding="utf-8", errors="replace").read().split("\n")
    pat = re.compile(r"^(?:[A-Za-z_][\w \*]*\s\**)?" + re.escape(name) + r"\(")
    for i, line in enumerate(lines):
        if pat.match(line) and not line.rstrip().endswith(";"):
            # include a preceding return-type line
            start = i - 1 if i > 0 and lines[i - 1] and not lines[i - 1].startswith(("}", "/", " ", "\t", "#")) else i
            for j in range(i, len(lines)):
                if lines[j] == "}":
                    return lines[start:j + 1]
    return [f"<{name} not found>"]


a, b = sys.argv[1], sys.argv[2]
for fn in sys.argv[3:]:
    la, lb = extract(a, fn), extract(b, fn)
    d = list(difflib.unified_diff(la, lb, a, b, lineterm="", n=2))
    print(f"== {fn}: {'identical' if not d else 'differs'}")
    for line in d:
        print(line)

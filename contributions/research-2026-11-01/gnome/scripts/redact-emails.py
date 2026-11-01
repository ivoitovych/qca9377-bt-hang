#!/usr/bin/env python3
"""redact-emails.py: replace e-mail addresses with <email> in the given text files, in place.

Usage: redact-emails.py <file>...
Prints the number of replacements per file. Files are rewritten only when something changed.
"""
import re
import sys

EMAIL = re.compile(r"[\w.+-]+@[\w-]+(?:\.[\w-]+)+")

for path in sys.argv[1:]:
    with open(path, encoding="utf-8", errors="surrogateescape") as fh:
        text = fh.read()
    new, n = EMAIL.subn("<email>", text)
    if n:
        with open(path, "w", encoding="utf-8", errors="surrogateescape") as fh:
            fh.write(new)
    print(f"{n:4d} {path}")

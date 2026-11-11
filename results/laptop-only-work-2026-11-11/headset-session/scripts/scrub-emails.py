#!/usr/bin/env python3
"""Replace e-mail addresses in the given text files by <email> (in place).
Used on this work area's own logs and scripts only.  Usage: scrub-emails.py <file>..."""
import re
import sys

rx = re.compile(r"[A-Za-z0-9._+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}")
for p in sys.argv[1:]:
    data = open(p, encoding="utf-8", errors="replace").read()
    new, n = rx.subn("<email>", data)
    if n:
        open(p, "w", encoding="utf-8").write(new)
    print("%s: %d replaced" % (p, n))

#!/usr/bin/env python3
"""send-table-check.py [<contributions dir>] — the "What to send" table of
contributions/README.md names what goes out, so every path in it must be one a
reader can copy: no "…" in a path, and every path must exist relative to the
contributions directory. Prints each problem; exits 1 if there is any, 2 if
the table is not found.

Why: the table first named its packages as `CO-44-…/send-20261113/`, which
cannot be copied, in the one place that says what to send (outside review
reaction, 2026-11-15)."""
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else
                    pathlib.Path(__file__).resolve().parent.parent / "contributions")
lines = (root / "README.md").read_text().split("\n")
start = next((i for i, l in enumerate(lines) if l.startswith("| CO | send this |")), None)
if start is None:
    print("send-table-check: no 'What to send' table in README.md")
    sys.exit(2)
end = start
while end < len(lines) and lines[end].startswith("|"):
    end += 1

rows = end - start - 2
if rows <= 0:
    # a header with nothing under it is not a table that passed
    print("send-table-check: the 'What to send' table has no rows — nothing was checked")
    sys.exit(2)
bad = 0
for i in range(start + 2, end):
    named = 0
    for tok in re.findall(r"`([^`]+)`", lines[i]):
        path = tok.split(" ")[0]
        if "/" not in path:
            continue            # a file name inside the named package, e.g. HELD.md
        named += 1
        if "…" in path or "..." in path:
            print(f"README.md:{i+1}: elided path {path}"); bad += 1
        elif not (root / path).exists():
            print(f"README.md:{i+1}: no such path {path}"); bad += 1
    if named == 0:
        print(f"README.md:{i+1}: a row that names no path: {lines[i][:60]}"); bad += 1
print(f"send-table-check: {rows} rows, {bad} problem(s)")
sys.exit(1 if bad else 0)

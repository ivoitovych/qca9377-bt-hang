#!/usr/bin/env python3
"""export-head.py: print the first N raw lines (repr) of a zstd journal export. Read only.

Usage: export-head.py <file.export.zst> [N]
"""
import subprocess
import sys

n = int(sys.argv[2]) if len(sys.argv) > 2 else 40
p = subprocess.Popen(["zstd", "-dcq", sys.argv[1]], stdout=subprocess.PIPE)
for i, line in enumerate(p.stdout):
    if i >= n:
        break
    print(repr(line[:120]))
p.kill()

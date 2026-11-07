#!/usr/bin/env python3
"""T011: every debian/patches/co03-*.patch has the DEP-3 fields
Description, Author, Origin, Applied-Upstream, Last-Update before '---'.
Usage: check-dep3.py <patch>..."""
import sys

need = ("Description", "Author", "Origin", "Applied-Upstream", "Last-Update")
bad = 0
for path in sys.argv[1:]:
    hdr = []
    for line in open(path):
        if line.rstrip("\n") == "---":
            break
        hdr.append(line)
    fields = {l.split(":", 1)[0] for l in hdr if l and not l[0].isspace() and ":" in l}
    missing = [f for f in need if f not in fields]
    print(f"{'OK ' if not missing else 'BAD'} {path.split('/')[-1]} {'missing ' + ','.join(missing) if missing else ''}")
    bad += bool(missing)
sys.exit(1 if bad else 0)

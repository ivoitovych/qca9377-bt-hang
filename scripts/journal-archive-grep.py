#!/usr/bin/env python3
"""archive-grep.py: search bt-archive's compressed journal exports for a message pattern.

Usage: archive-grep.py <regex> <boot-*.export.zst|.xz|.gz>...

Streams each archive through its decompressor and prints, per archive, the MESSAGE= lines
that match, with the entry's __REALTIME_TIMESTAMP rendered as local time; then a per-file
count. Files ending in .partial are skipped (still being written).
"""
import re
import subprocess
import sys
from datetime import datetime

DECOMP = {".zst": ["zstd", "-dcq"], ".xz": ["xz", "-dc"], ".gz": ["gzip", "-dc"]}


def main(argv):
    rx = re.compile(argv[0].encode())
    total = 0
    for path in argv[1:]:
        if path.endswith(".partial"):
            print(f"{path}: skipped (partial)")
            continue
        cmd = next((c for ext, c in DECOMP.items() if path.endswith(ext)), None)
        if not cmd:
            continue
        p = subprocess.Popen(cmd + [path], stdout=subprocess.PIPE)
        ts = b""
        n = 0
        for line in p.stdout:
            if line.startswith(b"__REALTIME_TIMESTAMP="):
                ts = line.split(b"=", 1)[1].strip()
            elif line.startswith(b"MESSAGE=") and rx.search(line):
                when = datetime.fromtimestamp(int(ts) / 1e6).strftime("%Y-%m-%d %H:%M:%S") if ts else "?"
                print(f"  {when}  {line[8:].decode(errors='replace').rstrip()}")
                n += 1
        p.wait()
        print(f"{path.rsplit('/', 1)[-1]}: {n} match(es)")
        total += n
    print(f"total: {total}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

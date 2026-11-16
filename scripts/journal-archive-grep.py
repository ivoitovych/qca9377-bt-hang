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
    not_searched = []
    for path in argv[1:]:
        if path.endswith(".partial"):
            print(f"{path}: skipped (partial)")
            continue
        cmd = next((c for ext, c in DECOMP.items() if path.endswith(ext)), None)
        if not cmd:
            print(f"{path}: NOT SEARCHED (unknown extension; known: {' '.join(DECOMP)})")
            not_searched.append(path)
            continue
        try:
            p = subprocess.Popen(cmd + [path], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        except OSError as e:
            print(f"{path}: NOT SEARCHED ({cmd[0]}: {e})")
            not_searched.append(path)
            continue
        ts = b""
        n = 0
        for line in p.stdout:
            if line.startswith(b"__REALTIME_TIMESTAMP="):
                ts = line.split(b"=", 1)[1].strip()
            elif line.startswith(b"MESSAGE=") and rx.search(line):
                when = datetime.fromtimestamp(int(ts) / 1e6).strftime("%Y-%m-%d %H:%M:%S") if ts else "?"
                print(f"  {when}  {line[8:].decode(errors='replace').rstrip()}")
                n += 1
        err = p.stderr.read().decode(errors="replace").strip()
        # a decompressor that failed part way leaves a count of what it got to,
        # which is not "0 matches" and not the archive's count
        if p.wait() != 0:
            print(f"{path.rsplit('/', 1)[-1]}: NOT SEARCHED COMPLETELY ({cmd[0]} failed: {err[:120]}); {n} match(es) before the failure")
            not_searched.append(path)
            total += n
            continue
        print(f"{path.rsplit('/', 1)[-1]}: {n} match(es)")
        total += n
    print(f"total: {total}")
    if not_searched:
        print(f"ERROR: {len(not_searched)} archive(s) were not (fully) searched: the total is NOT a count over all of them", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

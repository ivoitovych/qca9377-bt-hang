#!/usr/bin/env python3
"""archive-window.py: print journal-export messages in a local-time window that match a regex.

Usage: archive-window.py <regex> "<YYYY-MM-DD HH:MM:SS>" "<YYYY-MM-DD HH:MM:SS>" <boot-*.export.zst>

Streams the export through zstd. Like the project's journal-archive-grep.py it takes the
time from the last __REALTIME_TIMESTAMP line seen before a MESSAGE= line (robust against
binary fields), keeps messages in [from, to] (local time) that match the regex, and
prints the time with microseconds and the message. Bluetooth device addresses are
replaced by <addr> (colon and underscore forms) before printing. Read only.
Stops reading once the timestamps pass <to> by more than 60 s.
"""
import re
import subprocess
import sys
from datetime import datetime

ADDR = re.compile(rb"([0-9A-Fa-f]{2}[:_]){5}[0-9A-Fa-f]{2}")


def main(argv):
    if len(argv) != 4:
        print(__doc__)
        return 2
    rx = re.compile(argv[0].encode())
    t0 = int(datetime.strptime(argv[1], "%Y-%m-%d %H:%M:%S").timestamp() * 1e6)
    t1 = int(datetime.strptime(argv[2], "%Y-%m-%d %H:%M:%S").timestamp() * 1e6)
    p = subprocess.Popen(["zstd", "-dcq", argv[3]], stdout=subprocess.PIPE)
    us = 0
    n = 0
    for line in p.stdout:
        if line.startswith(b"__REALTIME_TIMESTAMP="):
            try:
                us = int(line.split(b"=", 1)[1])
            except ValueError:
                us = 0
            if us > t1 + 60_000_000:
                break
        elif line.startswith(b"MESSAGE=") and t0 <= us <= t1:
            msg = line[8:].rstrip(b"\n")
            if rx.search(msg):
                when = datetime.fromtimestamp(us / 1e6).strftime("%H:%M:%S.%f")
                print(f"{when} {ADDR.sub(b'<addr>', msg).decode(errors='replace')}")
                n += 1
    p.kill()
    p.wait()
    print(f"matches: {n}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

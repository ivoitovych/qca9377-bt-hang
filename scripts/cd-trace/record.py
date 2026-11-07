#!/usr/bin/env python3
"""Record CD-drive read activity and PipeWire timing side by side, passively.

  record.py <seconds> <outdir>

Writes <outdir>/sr0.tsv (every 0.25 s: wall time, sectors read since the previous sample,
read I/Os in flight) and <outdir>/pw-top.txt (pw-top batch output, one block per second, run as
the desktop user). Reads only /sys/block/sr0/stat; sends nothing to any device.
"""
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

secs = float(sys.argv[1])
out = Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)

pw = open(out / "pw-top.txt", "w")
pwp = subprocess.Popen(
    ["runuser", "-u", "i", "--", "env", "XDG_RUNTIME_DIR=/run/user/1000", "pw-top", "-b"],
    stdout=pw, stderr=subprocess.STDOUT)


def sectors():
    f = Path("/sys/block/sr0/stat").read_text().split()
    return int(f[2]), int(f[8])  # sectors read, I/Os currently in flight


end = time.time() + secs
prev, _ = sectors()
with open(out / "sr0.tsv", "w") as t:
    t.write("time\tsectors_read_delta\tinflight\n")
    while time.time() < end:
        time.sleep(0.25)
        cur, inflight = sectors()
        t.write(f"{datetime.now().strftime('%H:%M:%S.%f')[:-3]}\t{cur - prev}\t{inflight}\n")
        t.flush()
        prev = cur
pwp.terminate()
print("done", out)

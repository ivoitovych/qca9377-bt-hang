#!/usr/bin/env python3
"""live-test.py REMOTE DIR JOURNALCTL... : one journal file that is still being written.
DIR gets 20 archived files (written first), then a live file is fed through systemd-journal-remote's stdin in
three batches, with pauses (the file stays ONLINE while the writer is alive), its entries interleaved in time with
the archived files. Each JOURNALCTL is run as `-f -o export --directory=DIR -n all` and sees every batch as it
arrives; at the end the outputs are compared by SHA-256, and a plain non-follow read of the final directory is
compared too. Entries are kernel-like lines of one machine ID."""
import hashlib
import os
import signal
import subprocess
import sys
import time

REMOTE, D = sys.argv[1], sys.argv[2]
JCS = sys.argv[3:]
M = "0123456789abcdef0123456789abcdef"
os.makedirs(D)


def entry(rt, mono, boot, msg):
    return (f"__REALTIME_TIMESTAMP={rt}\n__MONOTONIC_TIMESTAMP={mono}\n_BOOT_ID={boot}\n_MACHINE_ID={M}\n_HOSTNAME=repro\n"
            f"_TRANSPORT=kernel\nSYSLOG_IDENTIFIER=kernel\nPRIORITY=6\nMESSAGE={msg}\n\n")


base = 1_700_000_000_000_000
boot_a = "00000001" + "b007" * 6
for i in range(20):
    lines = "".join(entry(base + (i * 1000 + e) * 2000, 5_000_000 + (i * 1000 + e) * 2000, boot_a, f"static {i} {e}") for e in range(1000))
    p = f"{D}/system@{i:05d}.journal"
    subprocess.run([REMOTE, f"--output={p}", "-"], input=lines.encode(), check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    with open(p, "r+b") as f:
        f.seek(16); f.write(b"\x02")

# the live file: same boot, entries in the time range of the archived files, in three batches
w = subprocess.Popen([REMOTE, f"--output={D}/system.journal", "-"], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL)
outs = {}
readers = []
for n, jc in enumerate(JCS):
    out = open(f"{D}.out{n}", "wb")
    outs[n] = f"{D}.out{n}"
    readers.append(subprocess.Popen([jc, "--no-pager", "-f", "-o", "export", f"--directory={D}", "-n", "all"],
                                    stdout=out, stderr=subprocess.DEVNULL))


def batch(first, count):
    data = "".join(entry(base + (first + e) * 2000 * 7, 5_000_000 + (first + e) * 2000 * 7, boot_a, f"live {first + e}") for e in range(count))
    w.stdin.write(data.encode()); w.stdin.flush()


time.sleep(2)
for first in (0, 1500, 3000):
    batch(first, 1500)
    time.sleep(4)
# a file added to the directory while the followers run: newer than everything so far, so every follower prints it
tmp = f"{D}.add.journal"
lines = "".join(entry(base + 80_000_000 + e * 2000, 5_000_000 + 80_000_000 + e * 2000, boot_a, f"added {e}") for e in range(300))
subprocess.run([REMOTE, f"--output={tmp}", "-"], input=lines.encode(), check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
with open(tmp, "r+b") as f:
    f.seek(16); f.write(b"\x02")
os.rename(tmp, f"{D}/system" + "@00099.journal")
time.sleep(4)
w.stdin.close()
w.wait(timeout=30)
time.sleep(4)
for r in readers:
    r.send_signal(signal.SIGTERM)
    r.wait(timeout=20)
res = {}
for n, jc in enumerate(JCS):
    data = open(outs[n], "rb").read()
    res[n] = (hashlib.sha256(data).hexdigest()[:16], data.count(b"__CURSOR="))
    print(f"follow read #{n} {jc}: {res[n][1]} entries, sha256 {res[n][0]}")
print("follow reads identical:", len({v for v in res.values()}) == 1)
fin = {}
for n, jc in enumerate(JCS):
    o = subprocess.run([jc, "--no-pager", "-o", "export", f"--directory={D}"], capture_output=True).stdout
    fin[n] = (hashlib.sha256(o).hexdigest()[:16], o.count(b"__CURSOR="))
    print(f"final read #{n} {jc}: {fin[n][1]} entries, sha256 {fin[n][0]}")
print("final reads identical:", len({v for v in fin.values()}) == 1)

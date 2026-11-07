#!/usr/bin/env python3
"""export-sco-context.py <boot-*.export.zst> "<from>" "<to>"

Streams one archived journal export (journalctl -o export, zstd) and prints the
kernel lines between two local times (journald reception time) that mark SCO
link teardown, ordered by the kernel's own printk time
(_SOURCE_MONOTONIC_TIMESTAMP):
  "hci0 hcon <p> handle N"  hci_conn_del() entry (hci_conn.c dynamic debug)
  "hci0 evt 5|6"            btusb_notify(): 5 = ENABLE_SCO_TRANSP, 6 = DISABLE_SCO
  "hci0: handle 0x.. reason" the host's Disconnect
  "opcode 0x0406 status"    the Disconnect's Command Status
  "corrupted SCO packet", "unknown connection handle", "Looking for Alt no :6"
Then classifies each "corrupted SCO packet" line as in corrupted-context.py.
Binary fields are skipped; no device addresses are printed.
"""
import re
import subprocess
import sys
from datetime import datetime

path, t_from, t_to = sys.argv[1], sys.argv[2], sys.argv[3]
lo = datetime.strptime(t_from, "%Y-%m-%d %H:%M:%S").timestamp() * 1e6
hi = datetime.strptime(t_to, "%Y-%m-%d %H:%M:%S").timestamp() * 1e6
marker = re.compile(r"^hci0 hcon \S+ handle \d+$|^hci0 evt [0-9]$|^hci0: handle 0x[0-9a-f]+ reason|^opcode 0x0406 status|corrupted SCO|unknown connection handle|^Looking for Alt no :[0-9]$|set USB alt|setting interface|submission failed|sending frame failed|^hci0 opcode 0x04(28|3d|29|3e) plen")

marker = re.compile(marker.pattern + r"|^hci0: conn add for device#")
dst_rx = re.compile(r"^hci0: dst ([0-9A-Fa-f:]{17}) handle (0x[0-9a-f]+)$")
peers = {}
p = subprocess.Popen(["zstd", "-dcq", path], stdout=subprocess.PIPE)
entry = {}
rows = []


def flush(e):
    rt = e.get(b"__REALTIME_TIMESTAMP")
    if not rt or e.get(b"_TRANSPORT") != b"kernel":
        return
    rt = int(rt)
    if not lo <= rt <= hi:
        return
    msg = e.get(b"MESSAGE", b"").decode(errors="replace")
    m = dst_rx.match(msg)
    if m:
        # hci_conn_add() debug: the remote address, replaced by a per-run number
        n = peers.setdefault(m.group(1).lower(), len(peers) + 1)
        msg = f"hci0: conn add for device#{n} handle {m.group(2)}"
    if marker.search(msg):
        src = int(e.get(b"_SOURCE_MONOTONIC_TIMESTAMP", e.get(b"__MONOTONIC_TIMESTAMP", b"0")))
        rows.append((src, rt, msg))


f = p.stdout
while True:
    line = f.readline()
    if not line:
        break
    if line == b"\n":
        flush(entry)
        entry = {}
        continue
    if b"=" in line:
        k, v = line.rstrip(b"\n").split(b"=", 1)
        entry[k] = v
    else:
        # binary field: name\n, le64 size, data, \n
        size = int.from_bytes(f.read(8), "little")
        f.read(size)
        f.read(1)
flush(entry)
p.wait()

rows.sort()
for src, rt, msg in rows:
    print(f"[{src / 1e6:14.6f}] {datetime.fromtimestamp(rt / 1e6).strftime('%H:%M:%S.%f')}  {msg}")

print()
for i, (src, rt, msg) in enumerate(rows):
    if "corrupted" not in msg:
        continue
    before = rows[:i]
    after = rows[i + 1:]
    dels = [r for r in before if r[2].startswith("hci0 hcon")]
    e6b = [r for r in before if r[2] == "hci0 evt 6"]
    e6a = [r for r in after if r[2] == "hci0 evt 6"]
    last_del = dels[-1] if dels else None
    kind = "mid-link"
    if last_del and e6a and (not e6b or e6b[-1][0] < last_del[0]):
        kind = "teardown"
    elif e6b and src - e6b[-1][0] < 200_000:
        kind = "after-evt6"
    rel = (lambda r: f"{(r[0] - src) / 1000:+.1f}ms" if r else "-")
    print(f"corrupted at [{src / 1e6:.6f}] {datetime.fromtimestamp(rt / 1e6).strftime('%H:%M:%S.%f')}: {kind}; "
          f"conn_del {rel(last_del)} ({last_del[2].split()[-1] if last_del else '-'}), next evt6 {rel(e6a[0] if e6a else None)}")

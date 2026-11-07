#!/usr/bin/env python3
"""sco-link-closure.py — every SCO/eSCO link in a run of bt-capture files, matched
by handle from its Synchronous Connect Complete to its Disconnection Complete,
with the real status bytes. Answers "did every link close?" from the radio
record, not from the kernel's debug text (sco-ledger.sh counts the kernel's
"opcode 0x0406 status" line, which hci_event_packet() prints with status 0 for
any Disconnection Complete while a Disconnect is pending, whatever its handle or
status).

  python3 -I scripts/sco-link-closure.py [--from "YYYY-MM-DD HH:MM:SS"] <capture.btsnoop>...
  python3 -I scripts/sco-link-closure.py [--from "YYYY-MM-DD HH:MM:SS"] <capture directory>

Captures in time order (bt-capture's monitor format, datalink 2001, hci0 only).
--from skips records before a local time (a boot's start). Read-only; prints no
addresses: headsets are numbered in order of first link.

Per link: setup time | headset # | link type | setup→disconnect s | who closed
(host: Disconnect command / remote: no command) | Disconnect's Command Status |
Disconnection Complete status and reason | latency command→complete.
Then totals, failed setups, links still open at the end of the last capture,
and any gap between consecutive files.
"""
import os
import struct
import sys
from datetime import datetime, timedelta

BTSNOOP_TS_OFFSET = 0x00E03AB44A676000  # btsnoop µs at 2000-01-01 (BlueZ's btsnoop)
UNIX_2000 = 946684800  # 2000-01-01 00:00 UTC; bt-capture writes µs since then + the offset
MON_COMMAND, MON_EVENT = 2, 3


def local(us):
    # bt-capture's clock is its recv() time, not the kernel's (its own comment)
    return datetime.fromtimestamp((us - BTSNOOP_TS_OFFSET) / 1e6 + UNIX_2000)


def records(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"btsnoop\0":
        sys.exit(f"{path}: not a btsnoop file")
    _ver, link = struct.unpack_from(">II", data, 8)
    if link != 2001:
        sys.exit(f"{path}: datalink {link}, expected 2001 (monitor)")
    off, n = 16, len(data)
    while off + 24 <= n:
        _olen, ilen, flags, _drops, ts = struct.unpack_from(">IIIIq", data, off)
        off += 24
        if off + ilen > n:
            break  # a record cut by the file's end (the live file)
        op = flags & 0xFFFF
        # every record is yielded (the gap check needs SCO/ACL data too); only
        # hci0's commands and events carry a payload
        if (flags >> 16) == 0 and op in (MON_COMMAND, MON_EVENT):
            yield ts, op, data[off:off + ilen]
        else:
            yield ts, None, b""
        off += ilen


def main(argv):
    since = None
    if len(argv) > 2 and argv[1] == "--from":
        since = datetime.strptime(argv[2], "%Y-%m-%d %H:%M:%S")
        argv = argv[2:]
    files = argv[1:]
    if not files:
        sys.exit(__doc__)
    if len(files) == 1 and os.path.isdir(files[0]):
        # a capture directory: its hci-YYYYMMDD-HHMMSS files in name order, from the
        # last one started at or before --from (bt-capture names a file by its start)
        d = files[0]
        files = sorted(os.path.join(d, f) for f in os.listdir(d)
                       if f.startswith("hci-") and f.endswith(".btsnoop"))
        if since:
            stamp = since.strftime("hci-%Y%m%d-%H%M%S")
            start = max([i for i, f in enumerate(files) if os.path.basename(f) <= stamp + ".btsnoop"] or [0])
            files = files[start:]
        print(f"files: {len(files)}, {os.path.basename(files[0])} to {os.path.basename(files[-1])}")
    peers, links, failed, open_ = {}, [], [], {}
    gaps, prev_last = [], None
    for path in files:
        first = last = None
        for ts, op, p in records(path):
            if since and local(ts) < since:
                continue
            first = first or ts
            last = ts
            if op is None:
                continue
            if op == MON_COMMAND and len(p) >= 6:
                opcode = struct.unpack_from("<H", p, 0)[0]
                if opcode == 0x0406:
                    h = struct.unpack_from("<H", p, 3)[0] & 0x0FFF
                    if h in open_:
                        open_[h].update(cmd=ts, cmd_reason=p[5])
            elif op == MON_EVENT and len(p) >= 2:
                code = p[0]
                if code == 0x2C and len(p) >= 2 + 10:  # Synchronous Connect Complete
                    st, h = p[2], struct.unpack_from("<H", p, 3)[0] & 0x0FFF
                    addr, ltype = bytes(p[5:11]), p[11]
                    peer = peers.setdefault(addr, len(peers) + 1)
                    if st:
                        failed.append((ts, peer, st))
                    else:
                        if h in open_:  # a handle reused with no Disconnection Complete seen
                            open_[h]["outcome"] = "REUSED-NO-COMPLETE"
                            links.append(open_.pop(h))
                        open_[h] = dict(t0=ts, peer=peer, h=h, ltype=ltype)
                elif code == 0x0F and len(p) >= 6:  # Command Status
                    st, opcode = p[2], struct.unpack_from("<H", p, 4)[0]
                    if opcode == 0x0406:
                        for L in open_.values():
                            if "cmd" in L and "cs" not in L:
                                L["cs"] = st
                elif code == 0x05 and len(p) >= 6:  # Disconnection Complete
                    st, h, reason = p[2], struct.unpack_from("<H", p, 3)[0] & 0x0FFF, p[5]
                    if h in open_:
                        L = open_.pop(h)
                        L.update(t1=ts, dc_status=st, dc_reason=reason)
                        L["outcome"] = "closed" if st == 0 else f"DC-STATUS-0x{st:02x}"
                        links.append(L)
        if first is not None:
            if prev_last is not None and first - prev_last > 5_000_000:
                gaps.append((local(prev_last), local(first)))
            prev_last = last
    for L in open_.values():
        L["outcome"] = "OPEN-AT-END"
        links.append(L)
    links.sort(key=lambda L: L["t0"])

    print(f"{'setup':26}  hs  type  {'held s':>9}  {'closed by':9}  cmd-st  dc-st  reason  {'ms':>6}  outcome")
    for L in links:
        t1 = L.get("t1")
        held = f"{(t1 - L['t0']) / 1e6:9.2f}" if t1 else f"{'-':>9}"
        by = ("host" if "cmd" in L else "remote") if t1 else "-"
        cs = f"0x{L['cs']:02x}" if "cs" in L else "-"
        dc = f"0x{L['dc_status']:02x}" if t1 else "-"
        rs = f"0x{L['dc_reason']:02x}" if t1 else "-"
        ms = f"{(t1 - L['cmd']) / 1e3:6.1f}" if t1 and "cmd" in L else f"{'-':>6}"
        ty = {0: "SCO", 2: "eSCO"}.get(L["ltype"], f"0x{L['ltype']:02x}")
        print(f"{local(L['t0']).isoformat(sep=' ', timespec='microseconds'):26}  {L['peer']:2}  {ty:4}  {held}  {by:9}  {cs:6}  {dc:5}  {rs:6}  {ms}  {L['outcome']}")

    closed = [L for L in links if L["outcome"] == "closed"]
    print(f"\nlinks {len(links)}   closed with Disconnection Complete status 0x00 {len(closed)}"
          f"   (by host {sum('cmd' in L for L in closed)}, by remote {sum('cmd' not in L for L in closed)})"
          f"   other outcomes {len(links) - len(closed)}")
    for peer in sorted(set(peers.values())):
        mine = [L for L in links if L["peer"] == peer]
        print(f"  headset {peer}: links {len(mine)}, closed {sum(L['outcome'] == 'closed' for L in mine)}")
    print(f"failed setups (Synchronous Connect Complete status != 0): {len(failed)}")
    for ts, peer, st in failed:
        print(f"  {local(ts).isoformat(sep=' ', timespec='microseconds')}  headset {peer}  status 0x{st:02x}")
    print(f"capture gaps over 5 s between files: {len(gaps)}")
    for a, b in gaps:
        print(f"  {a} -> {b}")
    if prev_last is not None:
        print(f"last record read: {local(prev_last)}")


if __name__ == "__main__":
    main(sys.argv)

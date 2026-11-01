#!/usr/bin/env python3
"""sco-orphans.py - SCO data against link lifetimes, from monitor-format captures.

  python3 -I sco-orphans.py --from "YYYY-MM-DD HH:MM:SS" --to "YYYY-MM-DD HH:MM:SS" <capture>...

Captures: btsnoop datalink 2001 (btmon -w / bt-capture), plain or .zst (read
through `zstd -dc`, nothing written to disk). Give them in time order.

The record order in a monitor capture is the order in which the kernel's
hci_rx_work() handed each received packet to the monitor, i.e. the order in
which it then processed them. So an SCO RX packet that comes after the
Disconnection Complete of its handle in the file is a packet the kernel
processed after it had deleted that connection: the "SCO packet for unknown
connection handle" case.

Prints, for hci0 only, no device addresses:
  LINK lines: setup (Synchronous Connect Complete), handle, link type, air mode,
    rx/tx packet length, the host's Disconnect, the Disconnection Complete,
    RX/TX packet counts while up, RX packets after the DC (count, first, last),
    and the gap from the last RX before the DC to the DC;
  ORPHAN lines: every SCO RX packet whose handle has no established link at that
    point of the file (time, handle, packet-status flags, length, and what the
    handle was: closed N s before, never seen);
  SETUP lines: every setup command and failed Synchronous Connect Complete;
  per-link RX packet-status flag counts (0 = correct, 1 = possibly invalid,
    2 = no data, 3 = partly lost) and RX length histogram.
"""
import os
import struct
import subprocess
import sys
from collections import Counter
from datetime import datetime

BTSNOOP_EPOCH_DELTA = 0x00DCDDB30F2F8000  # btsnoop us (0 AD) -> Unix epoch us


def local(us):
    return datetime.fromtimestamp((us - BTSNOOP_EPOCH_DELTA) / 1e6)


def stamp(us):
    return local(us).strftime("%Y-%m-%d %H:%M:%S.%f")


def open_capture(path):
    if path.endswith(".zst"):
        p = subprocess.Popen(["zstd", "-dc", path], stdout=subprocess.PIPE)
        return p.stdout, p
    return open(path, "rb"), None


def records(path):
    f, proc = open_capture(path)
    try:
        head = f.read(16)
        if head[:8] != b"btsnoop\0":
            sys.exit(f"{path}: not a btsnoop file")
        _ver, link = struct.unpack(">II", head[8:16])
        if link != 2001:
            sys.exit(f"{path}: datalink {link}, expected 2001")
        while True:
            h = f.read(24)
            if len(h) < 24:
                break
            _olen, ilen, flags, _drops, ts = struct.unpack(">IIIIq", h)
            if ilen > 65536 or not BTSNOOP_EPOCH_DELTA < ts < BTSNOOP_EPOCH_DELTA + 4_102_444_800_000_000:
                print(f"NOTE {os.path.basename(path)}: implausible record (len {ilen}, ts {ts}); rest of file skipped")
                break
            body = f.read(ilen)
            if len(body) < ilen:
                break
            yield ts, flags >> 16, flags & 0xFFFF, body
    finally:
        f.close()
        if proc:
            proc.wait()


def main(argv):
    args = argv[1:]
    t_from = t_to = None
    while args and args[0].startswith("--"):
        if args[0] == "--from":
            t_from = datetime.strptime(args[1], "%Y-%m-%d %H:%M:%S")
        elif args[0] == "--to":
            t_to = datetime.strptime(args[1], "%Y-%m-%d %H:%M:%S")
        else:
            sys.exit(__doc__)
        args = args[2:]
    if not args:
        sys.exit(__doc__)
    if len(args) == 1 and os.path.isdir(args[0]):
        # a capture directory: files named <prefix>-YYYYMMDD-HHMMSS.btsnoop[.zst]
        # in name order, from the last one started at or before --from to the
        # last one started before --to
        d = args[0]
        names = sorted(n for n in os.listdir(d)
                       if n.endswith((".btsnoop", ".btsnoop.zst")) and "-" in n)

        def start(n):
            parts = n.split(".")[0].split("-")
            return datetime.strptime(parts[-2] + parts[-1], "%Y%m%d%H%M%S")
        picked = []
        for i, n in enumerate(names):
            s = start(n)
            nxt = start(names[i + 1]) if i + 1 < len(names) else None
            if t_to and s > t_to:
                continue
            if t_from and nxt and nxt <= t_from:
                continue
            picked.append(os.path.join(d, n))
        args = picked
        print(f"files: {len(args)}: {os.path.basename(args[0])} to {os.path.basename(args[-1])}")

    live = {}      # handle -> link dict
    closed = {}    # handle -> last closed link dict
    links = []
    orphans = []
    setups = []
    first_ts = last_ts = None
    for path in args:
        for ts, idx, op, p in records(path):
            if idx != 0:
                continue
            if op in (0, 1):  # New Index / Delete Index: a new boot or a re-registration
                for L in live.values():
                    L["cut"] = True
                    links.append(L)
                live.clear()
            t = local(ts)
            if t_from and t < t_from:
                continue
            if t_to and t > t_to:
                break
            first_ts = first_ts or ts
            last_ts = ts
            if op == 2 and len(p) >= 3:  # command
                opcode = struct.unpack_from("<H", p, 0)[0]
                if opcode == 0x0406 and len(p) >= 6:
                    h = struct.unpack_from("<H", p, 3)[0] & 0x0FFF
                    if h in live:
                        live[h].setdefault("disc", ts)
                elif opcode in (0x0428, 0x043D, 0x0429, 0x043E):
                    up = ",".join(f"{h}{'(disc-pending)' if 'disc' in L else ''}" for h, L in live.items())
                    extra = ""
                    if opcode == 0x0428 and len(p) >= 3 + 17:
                        lat, voice, retr, pkt = struct.unpack_from("<HHBH", p, 3 + 10)
                        extra = f" max-latency 0x{lat:04x} voice 0x{voice:04x} retrans 0x{retr:02x} pkt-type 0x{pkt:04x}"
                    setups.append((ts, f"cmd 0x{opcode:04x}{extra} links-established-at-cmd [{up}]"))
            elif op == 3 and len(p) >= 2:  # event
                code = p[0]
                if code == 0x2C and len(p) >= 2 + 17:
                    st = p[2]
                    h = struct.unpack_from("<H", p, 3)[0] & 0x0FFF
                    ltype, rxl, txl, air = p[11], *struct.unpack_from("<HH", p, 14), p[18]
                    if st:
                        setups.append((ts, f"SyncConnComplete status 0x{st:02x} air 0x{air:02x}"))
                        continue
                    L = dict(h=h, t0=ts, ltype=ltype, air=air, rxl=rxl, txl=txl,
                             rx=0, tx=0, rx_after=[], tx_after=0, last_rx=None,
                             flags=Counter(), lens=Counter(), live_others=len(live))
                    if h in live:
                        live[h]["reused"] = True
                        links.append(live.pop(h))
                    live[h] = L
                    setups.append((ts, f"SyncConnComplete OK handle {h} air 0x{air:02x} type {ltype} "
                                       f"tx-interval {p[12]} retrans-window {p[13]} rx/tx-len {rxl}/{txl} "
                                       f"others-live {len(live) - 1}"))
                elif code == 0x05 and len(p) >= 6:
                    st = p[2]
                    h = struct.unpack_from("<H", p, 3)[0] & 0x0FFF
                    if h in live and st == 0:
                        L = live.pop(h)
                        L["t1"] = ts
                        L["reason"] = p[5]
                        links.append(L)
                        closed[h] = L
            elif op in (6, 7) and len(p) >= 3:  # SCO TX / RX
                raw = struct.unpack_from("<H", p, 0)[0]
                h, pf, dlen = raw & 0x0FFF, (raw >> 12) & 0x3, p[2]
                if h in live:
                    L = live[h]
                    if op == 7:
                        L["rx"] += 1
                        L["last_rx"] = ts
                        L["flags"][pf] += 1
                        L["lens"][dlen] += 1
                    else:
                        L["tx"] += 1
                elif op == 7:
                    C = closed.get(h)
                    what = f"closed {(ts - C['t1']) / 1e6:.3f} s before" if C else "never seen"
                    if C:
                        C["rx_after"].append(ts)
                    orphans.append((ts, h, pf, dlen, what, len(live)))
                elif h in closed:
                    closed[h]["tx_after"] += 1
    for L in live.values():
        links.append(L)
    links.sort(key=lambda L: L["t0"])

    print(f"window: {stamp(first_ts) if first_ts else '-'} to {stamp(last_ts) if last_ts else '-'}")
    for L in links:
        t1 = L.get("t1")
        held = f"{(t1 - L['t0']) / 1e6:.1f}s" if t1 else "open"
        disc = f"{(t1 - L['disc']) / 1e3:.1f}ms" if t1 and L.get("disc") else "remote/none"
        gap = f"{(t1 - L['last_rx']) / 1e3:.1f}ms" if t1 and L["last_rx"] else "-"
        ra = L["rx_after"]
        after = (f"{len(ra)} ({stamp(ra[0])[11:]} to {stamp(ra[-1])[11:]})" if ra else "0")
        print(f"LINK {stamp(L['t0'])} h={L['h']} type={L['ltype']} air=0x{L['air']:02x} "
              f"rxl={L['rxl']} txl={L['txl']} others-live={L['live_others']} held={held} "
              f"cmd->DC={disc} reason=0x{L.get('reason', 0):02x} rx={L['rx']} tx={L['tx']} "
              f"lastRX->DC={gap} rx_after_DC={after} tx_after_DC={L['tx_after']} "
              f"flags={dict(L['flags'])} lens={dict(L['lens'])}")
    for ts, what in setups:
        print(f"SETUP {stamp(ts)} {what}")
    for ts, h, pf, dlen, what, nlive in orphans:
        print(f"ORPHAN {stamp(ts)} h={h} pf={pf} len={dlen} {what} links-up={nlive}")
    print(f"links {len(links)}  orphan RX packets {len(orphans)}")


if __name__ == "__main__":
    main(sys.argv)

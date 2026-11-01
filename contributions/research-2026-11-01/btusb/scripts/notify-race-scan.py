#!/usr/bin/env python3
"""notify-race-scan.py <boot-*.export.zst | boot id>...

Looks, in kernel dynamic-debug lines, for the btusb notification race:
a SCO/eSCO setup is pending (hci_conn_add() "dst <addr> handle 0x0f.." directly
followed by a setup or accept command 0x0428/0x043d/0x0429/0x043e) and, before
its Synchronous Connection Complete reaches btusb_notify() ("hci0 evt 4" CVSD /
"hci0 evt 5" transparent) or the pending connection is deleted, btusb_notify()
is called with a non-SCO event ("hci0 evt 1" CONN_ADD, "evt 2" CONN_DEL,
"evt 3" VOICE_SETTING). btusb_notify() then records the new SCO count with
that non-SCO air mode, btusb_work() selects alternate setting 0 with a SCO
connection counted, and the link's own ENABLE notification no longer changes
the count, so it is ignored.

For each hit: the boot, times, the intervening event, and what followed: the
next evt 4/5 and whether "Looking for Alt no :6" (btusb_work() choosing an
alt for transparent air mode) came within 100 ms after it, and any
"set USB alt" / "submission failed" / "sending frame failed" line.
Also counts every pending setup and every evt 4/5 without a following
"Looking for Alt" (transparent only) in the whole input.

Input: archived journal exports (zstd) or, for a boot id, the system journal
(journalctl -k -b <id> -o export). No device addresses are printed.
"""
import re
import subprocess
import sys
from datetime import datetime

add_rx = re.compile(rb"^hci0: dst [0-9A-Fa-f:]{17} handle 0x0f[0-9a-f]{2}$")
setup_rx = re.compile(rb"^hci0 opcode 0x04(28|3d|29|3e) plen")
evt_rx = re.compile(rb"^hci0 evt ([0-9])$")
del_unset_rx = re.compile(rb"^hci0 hcon \S+ handle (3[89][0-9][0-9]|40[0-9][0-9])$")
alt6_rx = re.compile(rb"^Looking for Alt no :6$")
err_rx = re.compile(rb"set USB alt|submission failed|sending frame failed|setting interface failed")


def keep(msg):
    return bool(add_rx.match(msg) or setup_rx.match(msg) or evt_rx.match(msg) or
                del_unset_rx.match(msg) or alt6_rx.match(msg) or err_rx.search(msg))


def stream(src):
    if src.endswith(".zst"):
        return subprocess.Popen(["zstd", "-dcq", src], stdout=subprocess.PIPE)
    return subprocess.Popen(["journalctl", "-k", "-b", src, "-o", "export", "--no-pager"],
                            stdout=subprocess.PIPE)


def entries(src):
    p = stream(src)
    f = p.stdout
    e = {}
    while True:
        line = f.readline()
        if not line:
            break
        if line == b"\n":
            msg = e.get(b"MESSAGE", b"")
            if e.get(b"_TRANSPORT") == b"kernel" and keep(msg):
                yield (int(e.get(b"_SOURCE_MONOTONIC_TIMESTAMP", e.get(b"__MONOTONIC_TIMESTAMP", b"0"))),
                       int(e.get(b"__REALTIME_TIMESTAMP", b"0")), e[b"MESSAGE"])
            e = {}
            continue
        if b"=" in line:
            k, v = line.rstrip(b"\n").split(b"=", 1)
            if k in (b"MESSAGE", b"_TRANSPORT", b"__REALTIME_TIMESTAMP",
                     b"_SOURCE_MONOTONIC_TIMESTAMP", b"__MONOTONIC_TIMESTAMP"):
                e[k] = v
        else:
            size = int.from_bytes(f.read(8), "little")
            f.read(size)
            f.read(1)
    p.wait()


def t(rt):
    return datetime.fromtimestamp(rt / 1e6).strftime("%Y-%m-%d %H:%M:%S.%f")


tot_pending = tot_hits = tot_transp = tot_transp_noalt = 0
for src in sys.argv[1:]:
    rows = sorted(entries(src))
    pending = None      # (src_mono, rt) of a pending SCO setup
    last_add = None
    hits = []
    n_pending = 0
    transp = []         # (index, src_mono, rt) of evt 5
    for i, (mono, rt, msg) in enumerate(rows):
        if add_rx.match(msg):
            last_add = (mono, rt)
            continue
        if setup_rx.match(msg) and last_add and mono - last_add[0] < 5000:
            pending = dict(t=rt, mono=mono, events=[])
            n_pending += 1
            last_add = None
            continue
        last_add = None
        m = evt_rx.match(msg)
        if m:
            ev = int(m.group(1))
            if ev == 5:
                transp.append((i, mono, rt))
            if pending:
                if ev in (1, 2, 3):
                    pending["events"].append((rt, ev))
                elif ev in (4, 5, 6):
                    if pending["events"]:
                        pending["end"] = (rt, ev, i)
                        hits.append(pending)
                    pending = None
            continue
        if del_unset_rx.match(msg) and pending:
            if pending["events"]:
                pending["end"] = (rt, "deleted", i)
                hits.append(pending)
            pending = None
    # transparent ENABLE notifications not followed by btusb_work's alt search
    noalt = []
    for i, mono, rt in transp:
        ok = any(alt6_rx.match(m2) for mono2, rt2, m2 in rows[i + 1:i + 40] if mono2 - mono < 100_000)
        if not ok:
            noalt.append(rt)
    name = src.rsplit("/", 1)[-1]
    print(f"== {name}: pending SCO setups {n_pending}, race hits {len(hits)}, "
          f"transparent ENABLE {len(transp)}, of which without alt search {len(noalt)}")
    for h in hits:
        evs = ", ".join(f"evt {ev} at {t(rt)[11:]}" for rt, ev in h["events"])
        end = h["end"]
        i0 = end[2]
        tail = [m2.decode(errors="replace") for mono2, rt2, m2 in rows[i0:i0 + 400]
                if err_rx.search(m2) or alt6_rx.match(m2)][:4]
        print(f"  HIT setup {t(h['t'])} | {evs} | then {end[1] if isinstance(end[1], str) else 'evt ' + str(end[1])} at {t(end[0])[11:]} | after: {tail}")
    for rt in noalt:
        print(f"  ENABLE-TRANSP without alt search at {t(rt)}")
    tot_pending += n_pending
    tot_hits += len(hits)
    tot_transp += len(transp)
    tot_transp_noalt += len(noalt)
print(f"TOTAL pending SCO setups {tot_pending}, race hits {tot_hits}, transparent ENABLE {tot_transp}, without alt search {tot_transp_noalt}")

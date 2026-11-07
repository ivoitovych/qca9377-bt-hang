#!/usr/bin/env python3
"""Scan archived HCI captures (btsnoop monitor format, .zst) for the
abandoned-SCO-setup signatures that the CO-01 series is about.

Per file, counts:
  setup      Setup Synchronous Connection (0x0428) / Enhanced Setup (0x043d)
  accept     Accept Synchronous Connection Request (0x0429 / 0x043e)
  cancel     Create Connection Cancel (0x0408)
  cs_fail    Command Status != 0 for a setup opcode
  scc_ok     Synchronous Connection Complete status 0
  scc_fail   Synchronous Connection Complete status != 0
  cc_sco     Connection Complete (0x03) with link type SCO (0x00)
And prints one line per event of interest (no device addresses):
  CANCEL     a Create Connection Cancel, with the ms since the last SCO
             setup command and whether a setup was still pending
  CS-FAIL    a non-zero Command Status for a setup
  SCC-FAIL   a non-zero Synchronous Connection Complete
  ORPHAN?    a successful Synchronous Connection Complete arriving while
             no setup or accept was pending (possible late completion)
  SCC-DUP    a successful Synchronous Connection Complete while another
             SCO handle is already up (two links at once)

Usage: sco-setup-scan.py [--jobs N] <file.btsnoop[.zst]>...
"""
import os
import struct
import subprocess
import sys
from concurrent.futures import ProcessPoolExecutor
from datetime import datetime, timezone

EPOCH_DELTA = 0x00DCDDB30F2F8000
SETUP_OPS = {0x0428, 0x043D}
ACCEPT_OPS = {0x0429, 0x043E}


def ts_str(ts):
    us = ts - EPOCH_DELTA
    return datetime.fromtimestamp(us / 1e6, tz=timezone.utc).strftime("%Y-%m-%d %H:%M:%S.%f UTC")


def open_stream(path):
    if path.endswith(".zst"):
        p = subprocess.Popen(["zstd", "-dc", "--", path], stdout=subprocess.PIPE,
                             stderr=subprocess.DEVNULL)
        return p.stdout, p
    return open(path, "rb"), None


def scan(path):
    out = []
    counts = dict(setup=0, accept=0, cancel=0, cs_fail=0, scc_ok=0, scc_fail=0,
                  cc_sco=0, disc=0, records=0)
    f, proc = open_stream(path)
    try:
        hdr = f.read(16)
        if len(hdr) < 16 or hdr[:8] != b"btsnoop\0":
            return path, counts, [f"{os.path.basename(path)}: not btsnoop"]
        datalink = struct.unpack(">I", hdr[12:16])[0]
        if datalink != 2001:
            return path, counts, [f"{os.path.basename(path)}: datalink {datalink}, skipped"]
        pending = 0          # setups/accepts waiting for a completion
        last_setup_ts = None
        up = set()           # SCO handles up
        rh = struct.Struct(">IIIIq")
        while True:
            h = f.read(24)
            if len(h) < 24:
                break
            _orig, incl, flags, _drops, ts = rh.unpack(h)
            data = f.read(incl)
            if len(data) < incl:
                break
            counts["records"] += 1
            op = flags & 0xFFFF
            if op == 2 and incl >= 3:  # command
                opcode = data[0] | (data[1] << 8)
                if opcode in SETUP_OPS:
                    counts["setup"] += 1
                    pending += 1
                    last_setup_ts = ts
                elif opcode in ACCEPT_OPS:
                    counts["accept"] += 1
                    pending += 1
                elif opcode == 0x0408:
                    counts["cancel"] += 1
                    since = "-" if last_setup_ts is None else f"{(ts - last_setup_ts) / 1000:.1f}"
                    out.append(f"{ts_str(ts)}  CANCEL  ms-since-setup={since}  pending={pending}  up={len(up)}")
            elif op == 3 and incl >= 2:  # event
                evt = data[0]
                p = data[2:]
                if evt == 0x0F and len(p) >= 4:
                    status = p[0]
                    opcode = p[2] | (p[3] << 8)
                    if opcode in SETUP_OPS | ACCEPT_OPS and status:
                        counts["cs_fail"] += 1
                        pending = max(0, pending - 1)
                        out.append(f"{ts_str(ts)}  CS-FAIL  opcode=0x{opcode:04x} status=0x{status:02x}")
                elif evt == 0x0E and len(p) >= 4:
                    opcode = p[1] | (p[2] << 8)
                    if opcode == 0x0408:
                        out.append(f"{ts_str(ts)}  CANCEL-CC  status=0x{p[3]:02x}")
                elif evt == 0x2C and len(p) >= 10:
                    status = p[0]
                    handle = (p[1] | (p[2] << 8)) & 0x0FFF
                    ltype = p[9]
                    if status:
                        counts["scc_fail"] += 1
                        out.append(f"{ts_str(ts)}  SCC-FAIL  status=0x{status:02x} type={ltype} pending={pending}")
                    else:
                        counts["scc_ok"] += 1
                        if pending == 0:
                            out.append(f"{ts_str(ts)}  ORPHAN?  handle=0x{handle:03x} type={ltype} up={len(up)}")
                        if up:
                            out.append(f"{ts_str(ts)}  SCC-DUP  handle=0x{handle:03x} already-up={len(up)}")
                        up.add(handle)
                    pending = max(0, pending - 1)
                elif evt == 0x03 and len(p) >= 10:
                    if p[9] == 0x00:
                        counts["cc_sco"] += 1
                        out.append(f"{ts_str(ts)}  CC-SCO  status=0x{p[0]:02x}")
                elif evt == 0x05 and len(p) >= 4:
                    handle = (p[1] | (p[2] << 8)) & 0x0FFF
                    if handle in up:
                        counts["disc"] += 1
                        up.discard(handle)
    finally:
        f.close()
        if proc:
            proc.wait()
    return path, counts, out


def main(argv):
    jobs = 3
    if argv[:1] == ["--jobs"]:
        jobs = int(argv[1])
        argv = argv[2:]
    files = []
    for a in argv:
        if os.path.isdir(a):
            files += [os.path.join(a, n) for n in os.listdir(a)
                      if n.endswith(".btsnoop.zst") or n.endswith(".btsnoop")]
        else:
            files.append(a)
    files = sorted(files, key=os.path.basename)
    total = {}
    with ProcessPoolExecutor(max_workers=jobs) as ex:
        for path, counts, out in ex.map(scan, files):
            name = os.path.basename(path)
            print(f"== {name}  " + " ".join(f"{k}={v}" for k, v in counts.items()), flush=True)
            for line in out:
                print(f"   {line}")
            for k, v in counts.items():
                total[k] = total.get(k, 0) + v
    print("TOTAL files=%d " % len(files) + " ".join(f"{k}={v}" for k, v in total.items()))


if __name__ == "__main__":
    main(sys.argv[1:])

#!/usr/bin/env python3
"""msbc-check.py --from T --to T [--bucket S] <capture>... (or one capture directory)

For every transparent (mSBC) SCO link in the window, the payload stream of each
direction (TX host->controller, RX controller->host), concatenated in capture
order, checked as mSBC (HFP 1.7+, 60-byte frames: H2 header 0x01 + one of
0x08 0x38 0xc8 0xf8, then the 57-byte SBC frame starting with syncword 0xAD,
then one padding byte):

  frames      60-byte frames found at the alignment where the H2 header occurs
  h2-ok       frames whose H2 byte is the expected next one of the 4-cycle
  sync-ok     frames whose SBC part starts with 0xAD
  signal      frames whose 8 scale factors are not all zero (mSBC: 8 subbands,
              mono, so the 4 bytes after the 4-byte SBC header hold them)
  per bucket  frames / frames with signal / largest scale factor

Prints no addresses. Captures: btsnoop datalink 2001, plain or .zst.
"""
import os
import struct
import subprocess
import sys
from collections import defaultdict
from datetime import datetime

DELTA = 0x00DCDDB30F2F8000
H2 = [0x08, 0x38, 0xC8, 0xF8]


def local(us):
    return datetime.fromtimestamp((us - DELTA) / 1e6)


def records(path):
    if path.endswith(".zst"):
        p = subprocess.Popen(["zstd", "-dc", path], stdout=subprocess.PIPE)
        f = p.stdout
    else:
        p, f = None, open(path, "rb")
    try:
        if f.read(16)[:8] != b"btsnoop\0":
            sys.exit(f"{path}: not btsnoop")
        while True:
            h = f.read(24)
            if len(h) < 24:
                break
            _o, il, flags, _d, ts = struct.unpack(">IIIIq", h)
            b = f.read(il)
            if len(b) < il:
                break
            yield ts, flags >> 16, flags & 0xFFFF, b
    finally:
        f.close()
        if p:
            p.wait()


def analyse(stream, times, bucket):
    # find the alignment: the offset (0..59) with most H2 headers
    best, best_n = 0, -1
    for off in range(60):
        n = sum(1 for i in range(off, min(len(stream), 60 * 400), 60)
                if i + 1 < len(stream) and stream[i] == 0x01 and stream[i + 1] in H2)
        if n > best_n:
            best, best_n = off, n
    frames = h2ok = sync = sig = 0
    bad = []
    prev = None
    buckets = defaultdict(lambda: [0, 0, 0])
    i = best
    while i + 60 <= len(stream):
        fr = stream[i:i + 60]
        frames += 1
        if fr[0] == 0x01 and fr[1] in H2:
            idx = H2.index(fr[1])
            if prev is None or idx == (prev + 1) % 4:
                h2ok += 1
            else:
                bad.append((frames - 1, fr[:3].hex()))
            prev = idx
        else:
            bad.append((frames - 1, fr[:3].hex()))
            prev = None
        sbc = fr[2:59]
        sf_max = 0
        if sbc[0] == 0xAD:
            sync += 1
            sfs = []
            for b in sbc[4:8]:
                sfs += [b >> 4, b & 0xF]
            sf_max = max(sfs)
            if sf_max:
                sig += 1
        t = times[min(i, len(times) - 1)]
        k = int((t - times[0]) / 1e6 // bucket)
        bk = buckets[k]
        bk[0] += 1
        bk[1] += 1 if sf_max else 0
        bk[2] = max(bk[2], sf_max)
        i += 60
    if bad:
        runs = []
        for k, hx in bad:
            if runs and k == runs[-1][1] + 1:
                runs[-1][1] = k
            else:
                runs.append([k, k, hx])
        print("    not-ok frame runs (first..last index, first bytes): " +
              ", ".join(f"{a}..{b} {hx}" for a, b, hx in runs[:12]) +
              (f" (+{len(runs) - 12} more runs)" if len(runs) > 12 else ""))
    return best, frames, h2ok, sync, sig, buckets


def main(argv):
    a = argv[1:]
    tf = tt = None
    bucket = 1.0
    while a and a[0].startswith("--"):
        if a[0] == "--from":
            tf = datetime.strptime(a[1], "%Y-%m-%d %H:%M:%S")
        elif a[0] == "--to":
            tt = datetime.strptime(a[1], "%Y-%m-%d %H:%M:%S")
        elif a[0] == "--bucket":
            bucket = float(a[1])
        a = a[2:]
    if len(a) == 1 and os.path.isdir(a[0]):
        d = a[0]
        names = sorted(n for n in os.listdir(d) if n.endswith((".btsnoop", ".btsnoop.zst")))

        def st(n):
            p = n.split(".")[0].split("-")
            return datetime.strptime(p[-2] + p[-1], "%Y%m%d%H%M%S")
        pick = []
        for i, n in enumerate(names):
            nxt = st(names[i + 1]) if i + 1 < len(names) else None
            if tt and st(n) > tt:
                continue
            if tf and nxt and nxt <= tf:
                continue
            pick.append(os.path.join(d, n))
        a = pick
    live = {}
    done = []
    for path in a:
        for ts, idx, op, p in records(path):
            if idx != 0:
                continue
            t = local(ts)
            if tf and t < tf:
                continue
            if tt and t > tt:
                break
            if op == 3 and len(p) >= 19 and p[0] == 0x2C and p[2] == 0:
                h = struct.unpack_from("<H", p, 3)[0] & 0xFFF
                live[h] = dict(h=h, t0=ts, air=p[18], tx=bytearray(), rx=bytearray(), ttx=[], trx=[])
            elif op == 3 and len(p) >= 6 and p[0] == 0x05 and p[2] == 0:
                h = struct.unpack_from("<H", p, 3)[0] & 0xFFF
                if h in live:
                    L = live.pop(h)
                    L["t1"] = ts
                    done.append(L)
            elif op in (6, 7) and len(p) >= 3:
                h = struct.unpack_from("<H", p, 0)[0] & 0xFFF
                if h in live:
                    L = live[h]
                    key = "tx" if op == 6 else "rx"
                    data = p[3:3 + p[2]]
                    L[key] += data
                    L["t" + key] += [ts] * len(data)
    done += live.values()
    for L in sorted(done, key=lambda L: L["t0"]):
        if L["air"] != 0x03:
            continue
        print(f"LINK {local(L['t0'])} h={L['h']} held={((L.get('t1') or L['t0']) - L['t0']) / 1e6:.1f}s")
        for key in ("tx", "rx"):
            if not L[key]:
                print(f"  {key}: no data")
                continue
            off, n, h2, sy, sg, bk = analyse(bytes(L[key]), L["t" + key], bucket)
            print(f"  {key}: bytes {len(L[key])} align {off} frames {n} h2-ok {h2} sync-ok {sy} signal {sg}")
            base = L["t" + key][0]
            for k in sorted(bk):
                f, s, m = bk[k]
                print(f"    {local(base + int(k * bucket * 1e6)).strftime('%H:%M:%S')} frames {f:4} signal {s:4} max-sf {m}")


if __name__ == "__main__":
    main(sys.argv)

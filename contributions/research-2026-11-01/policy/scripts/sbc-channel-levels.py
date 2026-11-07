#!/usr/bin/env python3
"""sbc-channel-levels.py: like the project's scripts/sbc-frame-levels.py, but per channel.

Usage: python3 -I sbc-channel-levels.py --from "YYYY-MM-DD HH:MM:SS" --to "..." [--bucket N] <capture.btsnoop>...

For each bucket (default 1 s, local time) of outgoing SBC frames:
  time  config  frames  sig_L  sig_R  max_L  max_R
sig_L / sig_R: frames whose left / right scale factors are not all zero.
Scale factors in an SBC frame are stored channel by channel (left subbands, then right),
so they can be split without decoding. Mono frames count as left only.
Prints no addresses. The frame parser is the project's (scripts/sbc-frame-levels.py,
read 2026-11-01), extended by the channel split.
"""
import struct
import sys
from datetime import datetime

BTSNOOP_EPOCH_DELTA = 0x00DCDDB30F2F8000
OPCODE_ACL_TX = 4
FREQS = [16000, 32000, 44100, 48000]
MODES = ["MONO", "DUAL", "ST", "JS"]


def records(path):
    with open(path, "rb") as f:
        head = f.read(16)
        if head[:8] != b"btsnoop\0":
            raise SystemExit(f"{path}: not a btsnoop file")
        _v, datalink = struct.unpack(">II", head[8:16])
        if datalink != 2001:
            raise SystemExit(f"{path}: datalink {datalink}, expected 2001")
        while True:
            rec = f.read(24)
            if len(rec) < 24:
                return
            _o, incl, flags, _d, ts = struct.unpack(">IIIIq", rec)
            data = f.read(incl)
            if len(data) < incl:
                return
            yield flags & 0xFFFF, ts, data


def frames(payload):
    if len(payload) < 14 or (payload[0] & 0xC0) != 0x80:
        return
    count = payload[12] & 0x0F
    pos = 13
    for _ in range(count):
        if pos + 4 > len(payload) or payload[pos] != 0x9C:
            return
        b1, bitpool = payload[pos + 1], payload[pos + 2]
        freq = FREQS[(b1 >> 6) & 3]
        blocks = [4, 8, 12, 16][(b1 >> 4) & 3]
        mode = (b1 >> 2) & 3
        subbands = 8 if b1 & 1 else 4
        channels = 1 if mode == 0 else 2
        hdr = 4
        if mode == 3:
            hdr += 1 if subbands == 8 else 0
        sf_start = pos + hdr
        sf_bytes = payload[sf_start:sf_start + (4 * subbands * channels + 7) // 8]
        sfs = []
        for byte in sf_bytes:
            sfs.extend((byte >> 4, byte & 0x0F))
        sfs = sfs[:subbands * channels]
        left = sfs[:subbands]
        right = sfs[subbands:subbands * 2] if channels == 2 else []
        if mode in (0, 1):
            data_bits = blocks * channels * bitpool
        else:
            data_bits = (subbands if mode == 3 else 0) + blocks * bitpool
        length = 4 + (4 * subbands * channels) // 8 + (data_bits + 7) // 8
        if mode == 3 and subbands == 4:
            length = 4 + (4 + 4 * subbands * channels + data_bits + 7) // 8
        yield f"{freq}/{MODES[mode]}/bp{bitpool}", left, right
        pos += length


def main(argv):
    start = end = None
    bucket = 1
    files = []
    i = 0
    while i < len(argv):
        if argv[i] == "--from":
            start = datetime.strptime(argv[i + 1], "%Y-%m-%d %H:%M:%S"); i += 2
        elif argv[i] == "--to":
            end = datetime.strptime(argv[i + 1], "%Y-%m-%d %H:%M:%S"); i += 2
        elif argv[i] == "--bucket":
            bucket = int(argv[i + 1]); i += 2
        else:
            files.append(argv[i]); i += 1
    if not files:
        print(__doc__)
        return 2
    rows = {}
    for path in files:
        for opcode, ts, data in records(path):
            if opcode != OPCODE_ACL_TX or len(data) < 8:
                continue
            if ((data[1] >> 4) & 0x3) == 1:
                continue
            l2len, _cid = struct.unpack("<HH", data[4:8])
            payload = data[8:8 + l2len]
            when = datetime.fromtimestamp((ts - BTSNOOP_EPOCH_DELTA) / 1e6)
            if (start and when < start) or (end and when > end):
                continue
            key = when.replace(microsecond=0)
            key = key.replace(second=key.second - key.second % bucket)
            for config, left, right in frames(payload):
                r = rows.setdefault(key, {"c": [], "n": 0, "sl": 0, "sr": 0, "ml": 0, "mr": 0})
                if config not in r["c"]:
                    r["c"].append(config)
                r["n"] += 1
                if any(left):
                    r["sl"] += 1
                if any(right):
                    r["sr"] += 1
                r["ml"] = max(r["ml"], max(left) if left else 0)
                r["mr"] = max(r["mr"], max(right) if right else 0)
    if not rows:
        print("no SBC media frames found in the given files and window")
        return 1
    print("time                 config                          frames  sig_L  sig_R  max_L  max_R")
    for key in sorted(rows):
        r = rows[key]
        print(f"{key:%Y-%m-%d %H:%M:%S}  {','.join(r['c']):<30} {r['n']:6d} {r['sl']:6d} {r['sr']:6d} {r['ml']:6d} {r['mr']:6d}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

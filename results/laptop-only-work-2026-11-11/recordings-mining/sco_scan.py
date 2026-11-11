#!/usr/bin/env python3
"""sco_scan.py: one pass over btsnoop monitor-format captures (plain or .zst, read in memory).
Writes, to <outdir>:
  links.tsv    one row per SCO/eSCO link (setup cmd, connect complete, close, per-direction data stats)
  names.tsv    address-free: headset number -> name seen in Remote Name Request Complete / EIR
  perlink_sec.tsv   per link per direction per second: bytes, mSBC frames, valid CRC frames, frames with signal, CVSD activity
Headsets are numbered by first appearance; addresses are never written.
Usage: sco_scan.py <outdir> <file>...
"""
import os
import struct
import subprocess
import sys
from datetime import datetime

OFF = 0x00E03AB44A676000
U2000 = 946684800


def local(us):
    return datetime.fromtimestamp((us - OFF) / 1e6 + U2000)


def read_file(path):
    if path.endswith(".zst"):
        return subprocess.run(["zstd", "-dcq", path], capture_output=True, check=True).stdout
    with open(path, "rb") as f:
        return f.read()


def records(data):
    if data[:8] != b"btsnoop\0":
        return
    off, n = 16, len(data)
    while off + 24 <= n:
        _o, ilen, flags, _d, ts = struct.unpack_from(">IIIIq", data, off)
        off += 24
        if off + ilen > n:
            break
        yield ts, flags & 0xFFFF, flags >> 16, data[off:off + ilen]
        off += ilen


def crc8(bs):
    c = 0x0F
    for b in bs:
        for i in range(7, -1, -1):
            bit = (b >> i) & 1
            top = (c >> 7) & 1
            c = (c << 1) & 0xFF
            if top ^ bit:
                c ^= 0x1D
    return c


H2 = {0x08, 0x38, 0xC8, 0xF8}


def msbc_frames(buf):
    """yield (crc_ok, sf_list) for each frame found in a byte stream"""
    i = 0
    n = len(buf)
    while i + 60 <= n:
        if buf[i] == 0x01 and buf[i + 1] in H2 and buf[i + 2] == 0xAD and buf[i + 3] == 0 and buf[i + 4] == 0:
            f = buf[i + 2:i + 2 + 57]
            sfb = f[4:8]
            ok = crc8(bytes([f[1], f[2]]) + bytes(sfb)) == f[3]
            sf = []
            for b in sfb:
                sf += [b >> 4, b & 15]
            yield ok, sf
            i += 60
        else:
            i += 1


def cvsd_activity(buf):
    """number of bytes that are not the idle alternating pattern 0x55/0xAA, and number of 3-bit runs"""
    nonidle = sum(1 for b in buf if b not in (0x55, 0xAA))
    runs = 0
    prev_bits = 0
    # count runs of >=3 equal bits across the stream
    last = None
    run = 0
    for b in buf:
        for k in range(7, -1, -1):
            bit = (b >> k) & 1
            if bit == last:
                run += 1
                if run == 3:
                    runs += 1
            else:
                last = bit
                run = 1
    return nonidle, runs


def main():
    outdir = sys.argv[1]
    files = sys.argv[2:]
    amap = {}
    try:
        for ln in open("/root/exp/agent-work/laptop-evidence-mining-20261111/addrmap.private"):
            a, n = ln.rstrip("\n").split("\t")
            amap[bytes(int(x, 16) for x in a.split(":"))[::-1]] = n
    except OSError:
        pass
    peers = {}
    names = {}
    links = []
    open_ = {}
    pending_setup = []  # (ts, op, codec byte)
    closed_at = {}
    seclog = open(f"{outdir}/perlink_sec.tsv", "w")
    seclog.write("link_id\tdir\tsec_local\tpackets\tbytes\tframes\tcrc_ok\tsig_frames\tmaxsf_mean\tnonidle_bytes\tbitruns3\n")
    link_id = 0
    for path in files:
        try:
            data = read_file(path)
        except Exception as e:
            print("read fail", path, e, file=sys.stderr)
            continue
        base = os.path.basename(path)
        for ts, op, idx, p in records(data):
            if idx != 0:
                continue
            if op == 2 and len(p) >= 3:
                opc = struct.unpack_from("<H", p, 0)[0]
                if opc == 0x0428 and len(p) >= 3 + 17:
                    pending_setup.append((ts, "0428", "voice=%04x" % struct.unpack_from("<H", p, 3 + 2 + 8 + 2)[0]))
                elif opc == 0x043D and len(p) >= 3 + 59:
                    pending_setup.append((ts, "043d", "txfmt=%02x" % p[3 + 2 + 8]))
                elif opc == 0x0406 and len(p) >= 3 + 3:
                    h = struct.unpack_from("<H", p, 3)[0] & 0x0FFF
                    if h in open_:
                        open_[h]["disc_cmd"] = ts
            elif op == 3 and len(p) >= 2:
                code = p[0]
                if code == 0x07 and len(p) >= 2 + 7 + 3:
                    addr = bytes(p[3:9])
                    nm = bytes(p[9:9 + 248]).split(b"\0")[0].decode("utf-8", "replace")
                    if nm and p[2] == 0:
                        names[addr] = nm
                elif code == 0x2F and len(p) > 2 + 14:
                    # extended inquiry result: addr at 3..9 (after num responses), EIR at the end
                    addr = bytes(p[3:9])
                    eir = bytes(p[17:])
                    j = 0
                    while j + 1 < len(eir):
                        ln = eir[j]
                        if ln == 0:
                            break
                        t = eir[j + 1]
                        if t in (8, 9):
                            names.setdefault(addr, eir[j + 2:j + 1 + ln].decode("utf-8", "replace"))
                        j += ln + 1
                elif code == 0x2C and len(p) >= 19:
                    st = p[2]
                    h = struct.unpack_from("<H", p, 3)[0] & 0x0FFF
                    addr = bytes(p[5:11])
                    peer = peers.setdefault(addr, len(peers) + 1)
                    setup = pending_setup[-1] if pending_setup else None
                    L = dict(file=base, t0=ts, h=h, peer=peer, st=st, ltype=p[11], air=p[18], rxlen=struct.unpack_from("<H", p, 14)[0],
                             setup=setup, rx=bytearray(), tx=bytearray(), rxn=0, txn=0, rxfirst=None, rxlast=None, txfirst=None, txlast=None)
                    if st != 0:
                        L["t1"] = ts
                        L["outcome"] = "failed-0x%02x" % st
                        links.append(L)
                        pending_setup.clear()
                    else:
                        if h in open_:
                            o = open_.pop(h)
                            o["outcome"] = "reused-no-dc"
                            finish(o, links, seclog)
                        link_id += 1
                        L["id"] = link_id
                        L["secs"] = {}
                        open_[h] = L
                        pending_setup.clear()
                elif code == 0x05 and len(p) >= 6:
                    st = p[2]
                    h = struct.unpack_from("<H", p, 3)[0] & 0x0FFF
                    if h in open_:
                        L = open_.pop(h)
                        L["t1"] = ts
                        L["dc"] = (st, p[5])
                        L["outcome"] = "closed" if st == 0 else "dc-0x%02x" % st
                        L["file_end"] = base
                        closed_at[h] = (ts, L)
                        finish(L, links, seclog)
            elif op in (6, 7) and len(p) >= 3:
                h = struct.unpack_from("<H", p, 0)[0] & 0x0FFF
                L = open_.get(h)
                dlen = p[2]
                payload = p[3:3 + dlen]
                if L is None:
                    ca = closed_at.get(h)
                    if ca is not None and ts - ca[0] <= 3_000_000:
                        dd = "res_rx" if op == 7 else "res_tx"
                        ca[1][dd] = ca[1].get(dd, 0) + 1
                        ca[1]["res_last_ms"] = max(ca[1].get("res_last_ms", 0), (ts - ca[0]) / 1e3)
                        continue
                    unk = L_unknown.setdefault((op, base), 0)
                    L_unknown[(op, base)] = unk + 1
                    L_unknown_first.setdefault((op, base), ts)
                    continue
                d = "rx" if op == 7 else "tx"
                L[d + "n"] += 1
                if L[d + "first"] is None:
                    L[d + "first"] = ts
                L[d + "last"] = ts
                sec = int((ts - OFF) / 1e6 + U2000)
                s = L["secs"].setdefault((d, sec), [0, bytearray()])
                s[0] += 1
                s[1] += payload
    for h, L in open_.items():
        L["outcome"] = "open-at-end"
        finish(L, links, seclog)
    seclog.close()
    with open(f"{outdir}/links.tsv", "w") as o:
        o.write("id\tfile\tsetup_local\tpeer\tsetup_cmd\tlink_type\tair_mode\tstatus_or_outcome\tdc_status_reason\theld_s\tdisc_by_host\trx_pkts\ttx_pkts\trx_first_ms\trx_last_gap_to_close_ms\ttx_first_ms\tres_rx_after_dc\tres_tx_after_dc\tres_last_ms\n")
        for L in sorted(links, key=lambda L: L["t0"]):
            t1 = L.get("t1")
            held = "%.3f" % ((t1 - L["t0"]) / 1e6) if t1 else "-"
            o.write("\t".join(str(x) for x in [
                L.get("id", "-"), L["file"], local(L["t0"]).strftime("%Y-%m-%d %H:%M:%S.%f"), L["peer"],
                (L["setup"] or (0, "-", "-"))[1] + ":" + (L["setup"] or (0, "-", "-"))[2], L["ltype"], L["air"], L["outcome"],
                ("%02x/%02x" % L["dc"]) if L.get("dc") else "-", held, "host" if "disc_cmd" in L else "remote",
                L["rxn"], L["txn"],
                "%.1f" % ((L["rxfirst"] - L["t0"]) / 1e3) if L["rxfirst"] else "-",
                "%.1f" % ((t1 - L["rxlast"]) / 1e3) if (t1 and L["rxlast"]) else "-",
                "%.1f" % ((L["txfirst"] - L["t0"]) / 1e3) if L["txfirst"] else "-",
                L.get("res_rx", 0), L.get("res_tx", 0), "%.1f" % L.get("res_last_ms", 0)]) + "\n")
    with open(f"{outdir}/names.tsv", "w") as o:
        for a, p in sorted(peers.items(), key=lambda kv: kv[1]):
            o.write("%d\t%s\n" % (p, amap.get(a) or names.get(a, "?")))
    with open(f"{outdir}/unknown_data.tsv", "w") as o:
        o.write("dir\tfile\tpackets_for_handle_not_open\tfirst_local\n")
        for k, v in sorted(L_unknown.items()):
            o.write("%s\t%s\t%d\t%s\n" % ("rx" if k[0] == 7 else "tx", k[1], v, local(L_unknown_first[k]).strftime("%H:%M:%S.%f")))


L_unknown = {}
L_unknown_first = {}


def finish(L, links, seclog):
    secs = L.pop("secs", {})
    for (d, sec), (n, buf) in sorted(secs.items(), key=lambda kv: (kv[0][0], kv[0][1])):
        buf = bytes(buf)
        frames = crcok = sig = 0
        maxs = 0.0
        nonidle = runs = 0
        if L["air"] == 3:
            for ok, sf in msbc_frames(buf):
                frames += 1
                crcok += ok
                m = max(sf)
                maxs += m
                if m > 2:
                    sig += 1
        elif L["air"] == 2:
            nonidle, runs = cvsd_activity(buf)
        seclog.write("%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%.2f\t%d\t%d\n" % (
            L["id"], d, datetime.fromtimestamp(sec).strftime("%Y-%m-%d %H:%M:%S"), n, len(buf), frames, crcok, sig,
            (maxs / frames) if frames else 0.0, nonidle, runs))
    links.append(L)


main()

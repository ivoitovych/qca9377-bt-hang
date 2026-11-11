#!/usr/bin/env python3
"""usbmon_alt.py <out.tsv> <pcap>...: list SET_INTERFACE control requests (alt-setting changes) and their completion status
in usbmon pcaps (LINKTYPE_USB_LINUX_MMAPPED, 64-byte header). Read-only. Columns: local time, file, bus, dev, interface, alt, completion status."""
import struct
import sys
from datetime import datetime
from multiprocessing import Pool


def scan(path):
    out = []
    pend = {}
    with open(path, "rb") as f:
        data = f.read()
    if len(data) < 24:
        return out
    magic = data[:4]
    if magic == b"\xd4\xc3\xb2\xa1":
        e = "<"
    elif magic == b"\xa1\xb2\xc3\xd4":
        e = ">"
    else:
        return out
    off, n = 24, len(data)
    while off + 16 <= n:
        sec, usec, caplen, _ = struct.unpack_from(e + "IIII", data, off)
        off += 16
        rec = data[off:off + caplen]
        off += caplen
        if len(rec) < 64:
            continue
        rid = rec[0:8]
        typ = rec[8]
        xfer = rec[9]
        dev = rec[11]
        bus = struct.unpack_from("<H", rec, 12)[0]
        if xfer != 2:
            continue
        if typ == 0x53 and rec[14] == 0:  # 'S' with setup
            bm, br, wv, wi, wl = struct.unpack_from("<BBHHH", rec, 40)
            if bm == 0x01 and br == 0x0B:
                t = sec + usec / 1e6
                pend[rid] = (t, bus, dev, wi, wv)
        elif typ == 0x43 and rid in pend:
            t, bus, dev2, wi, wv = pend.pop(rid)
            st = struct.unpack_from("<i", rec, 28)[0]
            out.append((t, path.rsplit("/", 1)[-1], bus, dev2, wi, wv, st))
    return out


if __name__ == "__main__":
    res = []
    with Pool(8) as p:
        for r in p.imap(scan, sys.argv[2:]):
            res += r
    res.sort()
    with open(sys.argv[1], "w") as o:
        o.write("local\tfile\tbus\tdev\tiface\talt\tstatus\n")
        for t, fn, bus, dev, wi, wv, st in res:
            o.write("%s\t%s\t%d\t%d\t%d\t%d\t%d\n" % (datetime.fromtimestamp(t).strftime("%Y-%m-%d %H:%M:%S.%f"), fn, bus, dev, wi, wv, st))
    print(len(res), "set-interface requests")

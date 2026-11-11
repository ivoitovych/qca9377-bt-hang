import struct, sys, collections
d = open(sys.argv[1], "rb").read(40_000_000)
print(d[:4].hex(), struct.unpack_from("<I", d, 20)[0])
off = 24
c = collections.Counter()
shown = 0
while off + 16 <= len(d):
    s, u, cl, ol = struct.unpack_from("<IIII", d, off)
    off += 16
    r = d[off:off + cl]
    off += cl
    if len(r) < 64:
        break
    c[(chr(r[8]), r[9], r[11])] += 1
    if r[9] == 2 and shown < 6:
        shown += 1
        print(chr(r[8]), r[9], r[10], r[11], r[14], r[40:48].hex())
print(c.most_common(12))

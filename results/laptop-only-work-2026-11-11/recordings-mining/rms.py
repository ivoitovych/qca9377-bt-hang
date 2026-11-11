import array, math, sys
a = array.array("h")
a.frombytes(open(sys.argv[1], "rb").read())
n = len(a)
rms = math.sqrt(sum(x * x for x in a) / n) if n else 0
print(sys.argv[1].rsplit("/", 1)[-1], "samples", n, "rms %.1f" % rms, "peak", max(abs(x) for x in a) if n else 0, "nonzero %.2f%%" % (100.0 * sum(1 for x in a if x) / n if n else 0))
if len(sys.argv) > 2:
    step = int(sys.argv[2]) * 16000
    out = []
    for i in range(0, n - step + 1, step):
        c = a[i:i + step]
        out.append("%d" % math.sqrt(sum(x * x for x in c) / len(c)))
    print("rms per %ss:" % sys.argv[2], " ".join(out))

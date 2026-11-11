import datetime as dt
import glob
from collections import Counter

links = []
for d in ["s3A", "s3B1", "s3B2a", "s3B2b", "s3C"]:
    for l in list(open(f"/root/exp/agent-work/laptop-evidence-mining-20261111/{d}/links.tsv"))[1:]:
        p = l.split("\t")
        if p[9] == "-" or not p[7].startswith("closed"):
            continue
        t0 = dt.datetime.strptime(p[2], "%Y-%m-%d %H:%M:%S.%f")
        if float(p[9]) > 10000:
            continue
        links.append((t0, t0 + dt.timedelta(seconds=float(p[9]))))
msgs = []
for p in glob.glob("/root/exp/agent-work/laptop-evidence-mining-20261111/ext/*.tsv"):
    for line in open(p, errors="replace"):
        if "corrupted SCO packet" in line or "SCO packet for unknown connection handle" in line:
            f = line.split("\t", 6)
            kind = "corrupted" if "corrupted" in f[6] else "unknown-handle"
            msgs.append((dt.datetime.fromtimestamp(int(f[0]) / 1e6), kind))
msgs.sort()
res = Counter()
cov = 0
mn = min(l[0] for l in links)
for t, k in msgs:
    if t < mn:
        continue
    near = "none"
    for t0, t1 in links:
        if 0 <= (t - t1).total_seconds() <= 0.5:
            near = "0-500ms after DC"
            break
        if 0 <= (t - t0).total_seconds() <= 0.5:
            near = "0-500ms after connect-complete"
            break
        if t0 < t < t1:
            near = "during link"
    res[(k, near)] += 1
print("closed links considered", len(links), "from", mn)
for k, v in sorted(res.items()):
    print(k, v)

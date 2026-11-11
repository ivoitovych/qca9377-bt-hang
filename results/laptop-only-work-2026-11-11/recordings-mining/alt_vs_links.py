import datetime as dt
alts = []
for l in list(open("/root/exp/agent-work/laptop-evidence-mining-20261111/usb_alt.tsv"))[1:]:
    p = l.split("\t")
    alts.append((dt.datetime.strptime(p[0], "%Y-%m-%d %H:%M:%S.%f"), int(p[5]), int(p[6])))
links = []
for l in list(open("/root/exp/agent-work/laptop-evidence-mining-20261111/s3A/links.tsv"))[1:]:
    p = l.split("\t")
    t0 = dt.datetime.strptime(p[2], "%Y-%m-%d %H:%M:%S.%f")
    if p[9] != "-" and t0 >= dt.datetime(2026, 11, 4):
        links.append((t0, t0 + dt.timedelta(seconds=float(p[9])), p[7]))
print("links since 11-04 in capture:", len(links), " alt1 requests:", sum(1 for a in alts if a[1] == 1), " alt0 requests:", sum(1 for a in alts if a[1] == 0), " nonzero status:", sum(1 for a in alts if a[2] != 0))
d1, d0 = [], []
miss1 = miss0 = 0
for t0, t1, o in links:
    a1 = [a[0] for a in alts if a[1] == 1 and abs((a[0] - t0).total_seconds()) < 2]
    a0 = [a[0] for a in alts if a[1] == 0 and abs((a[0] - t1).total_seconds()) < 2]
    if a1: d1.append((a1[0] - t0).total_seconds() * 1000)
    else: miss1 += 1
    if a0: d0.append((a0[0] - t1).total_seconds() * 1000)
    else: miss0 += 1
print("alt1 after connect-complete ms: n", len(d1), "min %.1f max %.1f" % (min(d1), max(d1)), " missing", miss1)
print("alt0 after disconnection-complete ms: n", len(d0), "min %.1f max %.1f" % (min(d0), max(d0)), " missing", miss0)
# any alt request not near a link boundary
stray = 0
for t, alt, st in alts:
    near = any(abs((t - (l[0] if alt == 1 else l[1])).total_seconds()) < 2 for l in links)
    if not near:
        stray += 1
print("alt requests not within 2 s of a link boundary:", stray)

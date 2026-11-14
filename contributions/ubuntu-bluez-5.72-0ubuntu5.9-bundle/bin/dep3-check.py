"""DEP-3 headers of the bundle's patches: each needs Description or Subject, Author or From, Origin, Bug-Ubuntu, Last-Update
and either Applied-Upstream or Forwarded (the U23 patches have no upstream commit: Forwarded: no)."""
import glob, os, sys
P = "/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle/patches/"
series = [l.strip() for l in open(P + "series.fragment") if l.strip()]
bad = 0
for n in series:
    hdr = []
    for line in open(P + n):
        if line.rstrip("\n") == "---":
            break
        hdr.append(line)
    f = {l.split(":", 1)[0] for l in hdr if l and not l[0].isspace() and ":" in l}
    miss = []
    if not (f & {"Description", "Subject"}): miss.append("Description")
    if not (f & {"Author", "From"}): miss.append("Author")
    for k in ("Origin", "Bug-Ubuntu", "Last-Update"):
        if k not in f: miss.append(k)
    if not (f & {"Applied-Upstream", "Forwarded"}): miss.append("Applied-Upstream|Forwarded")
    print("BAD" if miss else "OK ", n, ",".join(miss))
    bad += bool(miss)
sys.exit(1 if bad else 0)

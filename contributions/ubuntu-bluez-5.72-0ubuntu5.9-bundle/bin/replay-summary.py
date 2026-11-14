import csv, collections, hashlib
D = "/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle/btmon-replay/out/"
rows = list(csv.DictReader(open(D + "results.tsv"), delimiter="\t"))
cells = collections.OrderedDict()
for r in rows:
    k = (r["capture"], r["opts"], r["width"])
    cells.setdefault(k, {})[r["variant"]] = r
print("cells:", len(cells), "runs:", len(rows))
sa = pa = ident = diff = 0
diffs = []
for k, v in cells.items():
    s, p = v["stock"], v["patched"]
    if s["exit"] == "134": sa += 1
    if p["exit"] != "0": pa += 1
    if s["exit"] == "0" and p["exit"] == "0":
        if s["stdout_sha256"] == p["stdout_sha256"]: ident += 1
        else: diff += 1; diffs.append(k)
print("stock aborts (134):", sa, " patched non-zero exits:", pa)
print("both exit 0: identical", ident, " different", diff)
print("stock aborts by width:", sorted({k[2] for k, v in cells.items() if v["stock"]["exit"] == "134"}, key=lambda x: (not x.isdigit(), int(x) if x.isdigit() else 0)))
for k in diffs:
    print("differs:", k)

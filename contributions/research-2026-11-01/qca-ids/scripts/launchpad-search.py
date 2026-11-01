#!/usr/bin/python3 -I
"""Search Launchpad (read only, anonymous API) for bug tasks matching each
query; write the raw JSON per query and a TSV of bug id, status, title,
date created, target.

Usage: launchpad-search.py <outdir> <query> [<query> ...]
"""
import json
import os
import sys
import urllib.parse
import urllib.request

UA = "qca9377-bt-hang/check"
outdir = sys.argv[1]
os.makedirs(outdir, exist_ok=True)
rows = {}
for q in sys.argv[2:]:
    url = ("https://api.launchpad.net/1.0/ubuntu?ws.op=searchTasks&ws.size=300"
           "&status=New&status=Incomplete&status=Confirmed&status=Triaged"
           "&status=In+Progress&status=Fix+Committed&status=Fix+Released"
           "&status=Won%27t+Fix&status=Invalid&status=Expired&status=Opinion"
           "&search_text=" + urllib.parse.quote(q))
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    data = json.load(urllib.request.urlopen(req, timeout=60))
    fn = os.path.join(outdir, "q-" + "".join(c if c.isalnum() else "_" for c in q) + ".json")
    with open(fn, "w") as f:
        json.dump(data, f)
    n = 0
    for e in data.get("entries", []):
        link = e.get("bug_link", "")
        bug = link.rsplit("/", 1)[-1]
        title = e.get("title", "")
        rows.setdefault(bug, [e.get("status"), title, e.get("date_created", "")[:10],
                              e.get("target_link", "").rsplit("/", 1)[-1], set()])
        rows[bug][4].add(q)
        n += 1
    print(f"{q}\t{n} tasks (total_size {data.get('total_size')})", file=sys.stderr)

with open(os.path.join(outdir, "summary.tsv"), "w") as f:
    f.write("bug\tstatus\tcreated\ttarget\tqueries\ttitle\n")
    for bug, (st, title, d, tgt, qs) in sorted(rows.items(), key=lambda r: r[1][2]):
        f.write(f"{bug}\t{st}\t{d}\t{tgt}\t{'; '.join(sorted(qs))}\t{title}\n")
print(f"{len(rows)} distinct bugs", file=sys.stderr)

#!/usr/bin/env python3
"""Read-only Launchpad query: published versions of the packages the session
kit is based on, in noble, per pocket, with publication dates.
Usage: freshness.py <outfile>   (also prints to stdout)"""
import json
import sys
import time
import urllib.parse
import urllib.request

API = "https://api.launchpad.net/devel"
PACKAGES = ["bluez", "pipewire", "wireplumber", "gnome-control-center",
            "gnome-bluetooth"]
SERIES = "noble"


def get(url):
    with urllib.request.urlopen(url, timeout=60) as r:
        return json.load(r)


lines = ["# queried %s UTC (Launchpad API, read only)"
         % time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime())]
for pkg in PACKAGES:
    q = urllib.parse.urlencode({
        "ws.op": "getPublishedSources", "source_name": pkg,
        "exact_match": "true", "distro_series": f"{API}/ubuntu/{SERIES}",
        "status": "Published"})
    pubs = get(API + "/ubuntu/+archive/primary?" + q)
    for p in pubs["entries"]:
        lines.append("%s %s %s %s %s" % (
            SERIES, pkg, p["source_package_version"], p["pocket"],
            p["date_published"]))
text = "\n".join(lines) + "\n"
sys.stdout.write(text)
if len(sys.argv) > 1:
    with open(sys.argv[1], "w") as f:
        f.write(text)

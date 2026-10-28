#!/usr/bin/env python3
"""Print Ubuntu's development series and the versions of a source package
(default pipewire) published in the newest series (Launchpad API, read only)."""
import json
import sys
import urllib.parse
import urllib.request

API = "https://api.launchpad.net/devel"
PACKAGE = sys.argv[1] if len(sys.argv) > 1 else "pipewire"


def get(url):
    with urllib.request.urlopen(url, timeout=60) as r:
        return json.load(r)


ubuntu = get(API + "/ubuntu")
print("current_series:", ubuntu["current_series_link"].rsplit("/", 1)[-1])
series = get(API + "/ubuntu/series")
for s in series["entries"][:4]:
    print("series:", s["name"], s["version"], s["status"])
    q = urllib.parse.urlencode({
        "ws.op": "getPublishedSources", "source_name": PACKAGE,
        "exact_match": "true", "distro_series": s["self_link"],
        "status": "Published"})
    pubs = get(API + "/ubuntu/+archive/primary?" + q)
    for p in pubs["entries"]:
        print("   ", p["source_package_version"], p["pocket"])

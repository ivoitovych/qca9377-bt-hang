#!/usr/bin/env python3
"""Print the versions of a source package (default bluez) published in
Ubuntu 24.04 (noble), per pocket (Launchpad API, read only)."""
import json
import sys
import urllib.parse
import urllib.request

API = "https://api.launchpad.net/devel"
PACKAGE = sys.argv[1] if len(sys.argv) > 1 else "bluez"
SERIES = sys.argv[2] if len(sys.argv) > 2 else "noble"


def get(url):
    with urllib.request.urlopen(url, timeout=60) as r:
        return json.load(r)


q = urllib.parse.urlencode({
    "ws.op": "getPublishedSources", "source_name": PACKAGE,
    "exact_match": "true", "distro_series": f"{API}/ubuntu/{SERIES}",
    "status": "Published"})
pubs = get(API + "/ubuntu/+archive/primary?" + q)
for p in pubs["entries"]:
    print(SERIES, p["source_package_version"], p["pocket"],
          p["date_published"])

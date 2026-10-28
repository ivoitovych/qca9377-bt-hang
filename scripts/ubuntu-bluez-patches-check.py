#!/usr/bin/env python3
"""Download the debian tarball of a bluez source version from Launchpad and list
which of its patches touch monitor/packet.c or monitor/display.c or mention the
two btmon commits.
Usage: dev-release-patches.py <version> <outdir>"""
import io
import json
import sys
import tarfile
import urllib.parse
import urllib.request

API = "https://api.launchpad.net/devel"
version, outdir = sys.argv[1], sys.argv[2]


def get(url):
    with urllib.request.urlopen(url, timeout=120) as r:
        return r.read()


q = urllib.parse.urlencode({"ws.op": "getPublishedSources", "source_name": "bluez",
                            "exact_match": "true", "version": version})
pubs = json.loads(get(API + "/ubuntu/+archive/primary?" + q))
src = pubs["entries"][0]["self_link"]
urls = json.loads(get(src + "?ws.op=sourceFileUrls"))
deb = [u for u in urls if u.endswith(".debian.tar.xz")][0]
print("debian tarball:", deb)
data = get(deb)
with open(f"{outdir}/{deb.rsplit('/', 1)[-1]}", "wb") as f:
    f.write(data)
with tarfile.open(fileobj=io.BytesIO(data), mode="r:xz") as tar:
    for m in tar.getmembers():
        if not m.isfile() or not m.name.startswith("debian/patches/"):
            continue
        text = tar.extractfile(m).read().decode("utf-8", "replace")
        hits = [k for k in ("monitor/packet.c", "monitor/display.c", "dca0f10f",
                            "fdbfe0018", "max_len", "print_packet")
                if k in text]
        if hits:
            print(m.name, hits)
    print("patches:", sum(1 for m in tar.getmembers()
                          if m.isfile() and m.name.startswith("debian/patches/")))
    names = [m.name for m in tar.getmembers() if m.name == "debian/patches/series"]
    print("series present:", bool(names))

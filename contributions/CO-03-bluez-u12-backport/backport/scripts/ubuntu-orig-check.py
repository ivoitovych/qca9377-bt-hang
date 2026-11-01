#!/usr/bin/env python3
"""Fetch the .orig.tar.xz of a bluez version published in Ubuntu
(Launchpad, read only), save it in <outdir>/<version>/, and look in the
release source itself for the code each commit adds:
  a14d59725ef3   transport.c: "cancel_resume", "transport_a2dp_remove_owner"
  664a5d3785a1   a2dp.c: "if (setup->reconfigure)" followed by "goto failed"
  0bed9886cff3   a2dp.c: "has no stream"
  a734b06059cb   adapter.c: "Wrong size of start discovery return parameters" twice
  fdbfe0018f6f   monitor/packet.c: "if (max_len <= 0)"
  dca0f10fd560   monitor/packet.c: "sizeof(line) - pos - 1"
Usage: ubuntu-orig-check.py <outdir> <version>..."""
import io
import json
import re
import sys
import tarfile
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://api.launchpad.net/devel"


def get(url):
    print("  read:", url)
    req = urllib.request.Request(url, headers={"User-Agent": "packaging-review (read only)"})
    with urllib.request.urlopen(req, timeout=300) as r:
        return r.read()


out = Path(sys.argv[1])
for version in sys.argv[2:]:
    print(f"== bluez {version}")
    q = urllib.parse.urlencode({"ws.op": "getPublishedSources", "source_name": "bluez",
                                "exact_match": "true", "version": version})
    src = json.loads(get(API + "/ubuntu/+archive/primary?" + q))["entries"][0]["self_link"]
    urls = json.loads(get(src + "?ws.op=sourceFileUrls"))
    orig = [u for u in urls if ".orig.tar." in u][0]
    data = get(orig)
    d = out / version
    d.mkdir(parents=True, exist_ok=True)
    (d / orig.rsplit("/", 1)[-1]).write_bytes(data)
    files = {}
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:*") as tar:
        for m in tar.getmembers():
            for want in ("profiles/audio/transport.c", "profiles/audio/a2dp.c",
                         "src/adapter.c", "monitor/packet.c", "configure.ac"):
                if m.isfile() and m.name.endswith("/" + want):
                    files[want] = tar.extractfile(m).read().decode("utf-8", "replace")
    ver = re.search(r"AC_INIT\(\[?bluez\]?, *\[?([0-9.]+)", files["configure.ac"])
    print("  configure.ac version:", ver.group(1) if ver else "?")
    t, a, ad, p = (files["profiles/audio/transport.c"], files["profiles/audio/a2dp.c"],
                   files["src/adapter.c"], files["monitor/packet.c"])
    checks = [
        ("a14d59725ef3 (transport.c cancel_resume)", "cancel_resume" in t and "transport_a2dp_remove_owner" in t),
        ("664a5d3785a1 (a2dp.c reconfigure early fail)", len(re.findall(r"if \(setup->reconfigure\)\n\t\tgoto failed;", a)) >= 2),
        ("0bed9886cff3 (a2dp.c 'has no stream')", "has no stream" in a),
        ("a734b06059cb (adapter.c second size check)", ad.count("Wrong size of start discovery return parameters") >= 2),
        ("fdbfe0018f6f (packet.c max_len <= 0)", "if (max_len <= 0)" in p),
        ("dca0f10fd560 (packet.c clamp to sizeof(line))", "sizeof(line) - pos - 1" in p),
    ]
    for name, ok in checks:
        print(f"  {name}: {'PRESENT' if ok else 'ABSENT'}")

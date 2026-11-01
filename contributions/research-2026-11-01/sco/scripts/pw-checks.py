#!/usr/bin/env python3
"""Print patchwork check records (context, state, date, description, target URL)
for patch ids; only contexts matching an optional regex.

Usage: pw-checks.py <regex or -> <patch id>...
"""
import json
import re
import sys
import urllib.request


def main(rx, ids):
    pat = None if rx == "-" else re.compile(rx)
    for pid in ids:
        url = f"https://patchwork.kernel.org/api/patches/{pid}/checks/"
        req = urllib.request.Request(url, headers={"User-Agent": "research-sco/1"})
        with urllib.request.urlopen(req, timeout=60) as r:
            checks = json.load(r)
        for c in checks:
            if pat and not pat.search(c.get("context", "")):
                continue
            print(f"{pid}  {c.get('date')}  {c.get('context')}  {c.get('state')}  "
                  f"{c.get('description')}  {c.get('target_url')}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])

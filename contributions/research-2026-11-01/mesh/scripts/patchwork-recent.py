#!/usr/bin/env python3
"""patchwork-recent.py — the bluetooth project's patches posted since a date.

    python3 -I scripts/patchwork-recent.py SINCE [REGEX]

SINCE is YYYY-MM-DD (UTC). One line per patch, oldest first: id, state, the
date posted, the submitter and the subject; with REGEX (case-insensitive) only
the patches whose subject matches. A count closes the list. The question it
answers recurs at every watch round: has anyone else posted in this area since
we last looked? Read-only; the raw listing is kept under tmp/patchwork/ as
recent-<SINCE>.json so the claim ships with its extraction. Exits 2 when the
API cannot be reached.
"""
import json
import os
import re
import sys
import urllib.request

API = ("https://patchwork.kernel.org/api/patches/?project=bluetooth"
       "&since={}T00:00:00&order=date&per_page=250")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tmp", "patchwork")


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "curl/8"})
    with urllib.request.urlopen(req, timeout=120) as r:
        link = r.headers.get("Link", "")
        return json.load(r), link


def next_url(link):
    for part in link.split(","):
        if 'rel="next"' in part:
            return part.split(";")[0].strip().strip("<>")
    return None


def main(args):
    if not args or not re.fullmatch(r"\d{4}-\d\d-\d\d", args[0]):
        print(__doc__.strip().splitlines()[2].strip(), file=sys.stderr)
        return 1
    since = args[0]
    pat = re.compile(args[1], re.I) if len(args) > 1 else None
    patches = []
    url = API.format(since)
    try:
        while url:
            page, link = get(url)
            patches.extend(page)
            url = next_url(link)
    except OSError as e:
        print(f"unreachable: {e}", file=sys.stderr)
        return 2
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, f"recent-{since}.json"), "w") as f:
        json.dump(patches, f, indent=1)
    shown = 0
    for p in patches:
        if pat and not pat.search(p["name"]):
            continue
        who = p["submitter"].get("name") or p["submitter"].get("email")
        print(f"{p['id']}  {p['state']:<18} {p['date'][:16]}  {who}  {p['name']}")
        shown += 1
    print(f"-- {shown} of {len(patches)} patches since {since}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

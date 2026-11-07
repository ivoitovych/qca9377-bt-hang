#!/usr/bin/env python3
"""Read-only gitlab.freedesktop.org API reader for this research.

Usage:
  gitlab.py issue <group/project> <iid>        issue + all notes, saved as JSON under web/gitlab/
  gitlab.py mr <group/project> <iid>           merge request + notes
  gitlab.py search <group/project> <terms...>  issues matching the terms (title + description)
  gitlab.py searchmr <group/project> <terms...>
Only GET requests. Never signs in, never writes.
"""
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

BASE = "https://gitlab.freedesktop.org/api/v4"
UA = "qca9377-bt-hang/check"
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "web", "gitlab")


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))


def proj(p):
    return urllib.parse.quote(p, safe="")


def save(name, data):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1, ensure_ascii=False)
    return path


def show_item(kind, p, iid):
    seg = "issues" if kind == "issue" else "merge_requests"
    item = get(f"{BASE}/projects/{proj(p)}/{seg}/{iid}")
    notes = []
    try:
        page = 1
        while True:
            batch = get(f"{BASE}/projects/{proj(p)}/{seg}/{iid}/notes?per_page=100&page={page}&sort=asc")
            notes.extend(batch)
            if len(batch) < 100:
                break
            page += 1
    except urllib.error.HTTPError:
        # the notes API asks for a sign-in here; the public page's discussions JSON does not
        web = "issues" if kind == "issue" else "merge_requests"
        disc = get(f"https://gitlab.freedesktop.org/{p}/-/{web}/{iid}/discussions.json")
        for d in disc:
            for n in d.get("notes", []):
                notes.append({
                    "system": n.get("system"),
                    "created_at": n.get("created_at"),
                    "author": {"username": (n.get("author") or {}).get("username")},
                    "body": n.get("note") if n.get("note") is not None else n.get("body"),
                })
    tag = p.split("/")[-1]
    path = save(f"{tag}-{kind}-{iid}.json", {"item": item, "notes": notes})
    print(f"# {item.get('web_url')}")
    print(f"title: {item.get('title')}")
    print(f"state: {item.get('state')}  created: {item.get('created_at')}  closed: {item.get('closed_at')}  labels: {item.get('labels')}")
    if kind == "mr":
        print(f"merged: {item.get('merged_at')}  merge_commit: {item.get('merge_commit_sha')}")
    print(f"author: {(item.get('author') or {}).get('username')}")
    print("--- description ---")
    print(item.get("description") or "")
    for n in notes:
        if n.get("system"):
            print(f"--- [system] {n.get('created_at')}: {n.get('body')}")
            continue
        print(f"--- note {n.get('created_at')} by {(n.get('author') or {}).get('username')} ---")
        print(n.get("body") or "")
    print(f"(saved {path})")


def search(kind, p, terms):
    seg = "issues" if kind == "search" else "merge_requests"
    q = urllib.parse.quote(" ".join(terms))
    res = []
    page = 1
    while page <= 5:
        batch = get(f"{BASE}/projects/{proj(p)}/{seg}?search={q}&in=title,description&per_page=100&page={page}&order_by=created_at")
        res.extend(batch)
        if len(batch) < 100:
            break
        page += 1
    for it in res:
        print(f"{it.get('iid')}\t{it.get('state')}\t{(it.get('created_at') or '')[:10]}\t{(it.get('closed_at') or '')[:10]}\t{it.get('title')}")
    print(f"({len(res)} results for {' '.join(terms)!r})")


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        return 2
    cmd, p = sys.argv[1], sys.argv[2]
    if cmd in ("issue", "mr"):
        show_item(cmd, p, sys.argv[3])
    elif cmd in ("search", "searchmr"):
        search(cmd, p, sys.argv[3:])
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())

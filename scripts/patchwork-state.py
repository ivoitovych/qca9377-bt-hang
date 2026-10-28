#!/usr/bin/env python3
"""patchwork-state.py — the state of patches on patchwork.kernel.org.

    python3 -I scripts/patchwork-state.py [--files] ID [ID ...]

One line per patch: id, state, the date it was posted, the submitter, the
number of comments (the bots' included), the commit it was applied as (when
patchwork recorded one) and the subject. With --files, the files each patch's
diff touches follow its line ("does another author's patch touch our file?").
"Still new, no reply" was checked by
hand on every watch round; this reads the same public API. Read-only; the raw
JSON is kept under tmp/patchwork/ so the claim ships with its extraction.
Exits 2 when the API cannot be reached.
"""
import json
import os
import sys
import urllib.request

API = "https://patchwork.kernel.org/api/patches/{}/"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tmp", "patchwork")


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "curl/8"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def diff_files(diff):
    files = []
    for line in (diff or "").splitlines():
        if line.startswith("+++ ") and line[4:] != "/dev/null":
            files.append(line[4:].split("/", 1)[-1])
    return files


def main(ids):
    files = bool(ids) and ids[0] == "--files"
    if files:
        ids = ids[1:]
    if not ids:
        print(__doc__.strip().splitlines()[2].strip(), file=sys.stderr)
        return 1
    os.makedirs(OUT, exist_ok=True)
    for pid in ids:
        try:
            p = get(API.format(pid))
            comments = get(p["comments"]) if p.get("comments") else []
        except OSError as e:
            print(f"{pid}  unreachable: {e}", file=sys.stderr)
            return 2
        with open(os.path.join(OUT, f"patch-{pid}.json"), "w") as f:
            json.dump({"patch": p, "comments": comments}, f, indent=1)
        who = p["submitter"].get("name") or p["submitter"].get("email")
        ref = p.get("commit_ref") or "-"
        print(f"{pid}  {p['state']:<12} {p['date'][:16]}  {who}  "
              f"comments={len(comments)}  commit={ref}  {p['name']}")
        if files:
            for path in diff_files(p.get("diff")):
                print(f"    file: {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

#!/usr/bin/env python3
"""Print the comments recorded in tmp/patchwork/patch-<id>.json (written by
patchwork-state.py): date, submitter name, and the first non-quoted lines."""
import json
import os
import sys

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tmp", "patchwork")


def main(ids):
    for pid in ids:
        with open(os.path.join(OUT, f"patch-{pid}.json")) as f:
            data = json.load(f)
        comments = data.get("_comments") or data.get("comments_list") or []
        if not comments:
            for k, v in data.items():
                if isinstance(v, list) and v and isinstance(v[0], dict) and "content" in v[0]:
                    comments = v
        print(f"== {pid}: {len(comments)} comments; keys={sorted(data.keys())[:12]}")
        for c in comments:
            sub = c.get("submitter", {})
            body = [l for l in (c.get("content") or "").splitlines() if l.strip() and not l.startswith(">")]
            print(f"  {c.get('date')}  {sub.get('name')}  subject={c.get('subject')!r}")
            for l in body[:8]:
                print(f"      {l[:150]}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

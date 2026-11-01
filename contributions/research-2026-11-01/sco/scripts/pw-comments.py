#!/usr/bin/env python3
"""Print the comments kept in patchwork-state JSON files: date, submitter, first lines.

Usage: pw-comments.py <patch-N.json>...
"""
import json
import sys


def main(paths):
    for p in paths:
        with open(p) as f:
            d = json.load(f)
        comments = d.get("_comments") or d.get("comments_list") or d.get("comments") or []
        if isinstance(comments, str):
            print(f"{p}: comments is a URL only: {comments}")
            continue
        print(f"== {p}: {d.get('name')} ({len(comments)} comments)")
        for c in comments:
            sub = c.get("submitter") or {}
            name = sub.get("name") if isinstance(sub, dict) else sub
            print(f"-- {c.get('date')}  {name}")
            body = (c.get("content") or "").splitlines()
            for line in body[:40]:
                print("   " + line)
            if len(body) > 40:
                print(f"   ... ({len(body)} lines)")


if __name__ == "__main__":
    main(sys.argv[1:])

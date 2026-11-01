#!/usr/bin/env python3
"""Print the reviews of a saved sashiko /api/patchset JSON.

Usage: sashiko-reviews.py <patchset.json> [max lines per review]
Mail addresses are replaced by <addr>.
"""
import json
import re
import sys

ADDR = re.compile(r"[\w.+-]+@[\w-]+(\.[\w-]+)+")


def clean(s):
    return ADDR.sub("<addr>", s or "")


def main(path, maxlines):
    d = json.load(open(path))
    print(clean(f"patchset {d.get('id')} status={d.get('status')} subject={d.get('subject')}"))
    for p in d.get("patches", []):
        print(clean(f"patch id={p.get('id')} part={p.get('part_index')} subject={p.get('subject')} status={p.get('status')}"))
    for r in d.get("reviews", []):
        keys = [k for k in r.keys()]
        print("=" * 70)
        print(clean(f"review keys: {keys}"))
        for k in ("patch_id", "status", "result", "summary", "verdict", "created_at"):
            if k in r:
                print(clean(f"{k}: {r[k]}"))
        text = r.get("inline_review") or r.get("output") or r.get("review") or r.get("content") or ""
        if isinstance(text, (dict, list)):
            text = json.dumps(text, indent=1)
        lines = clean(text).splitlines()
        for line in lines[:maxlines]:
            print("  " + line)
        if len(lines) > maxlines:
            print(f"  ... {len(lines)} lines")


if __name__ == "__main__":
    main(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 200)

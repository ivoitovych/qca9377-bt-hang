#!/usr/bin/env python3
"""json-summary.py: print chosen fields of a GitLab/Launchpad JSON file (object or list).

Usage: json-summary.py <file.json> [field ...]
Default fields: iid title state created_at updated_at closed_at web_url labels milestone.
For a list, one block per element. A field 'description' is cut to 1200 characters.
Email-like strings are replaced by <email>.
"""
import json
import re
import sys

EMAIL = re.compile(r"[\w.+-]+@[\w-]+(\.[\w-]+)+")
DEFAULT = ["iid", "title", "state", "created_at", "updated_at", "closed_at",
           "web_url", "labels", "milestone"]


def show(obj, fields):
    for f in fields:
        v = obj.get(f)
        if isinstance(v, dict):
            v = v.get("title") or v.get("name") or v
        s = str(v)
        if f in ("description", "body", "message", "content"):
            s = s[:1200]
        print(f"  {f}: {EMAIL.sub('<email>', s)}")
    print("  --")


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    with open(argv[0], encoding="utf-8") as fh:
        data = json.load(fh)
    fields = argv[1:] or DEFAULT
    if isinstance(data, dict) and "entries" in data:
        data = data["entries"]
    if isinstance(data, list):
        print(f"{len(data)} element(s)")
        for o in data:
            show(o, fields)
    else:
        show(data, fields)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

#!/usr/bin/env python3
"""pw-list.py <patchwork patches JSON>... - one line per patch: id, state, date,
submitter name, subject (no mail addresses)."""
import json
import sys

for path in sys.argv[1:]:
    with open(path) as f:
        data = json.load(f)
    for p in data:
        sub = p.get("submitter") or {}
        name = (sub.get("name") or "?")[:24]
        print(f"{p['id']} {p['state']:12} {p['date'][:16]} {name:24} {p['name']}")

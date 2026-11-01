#!/usr/bin/env python3
"""pw-show.py <patchwork patch JSON> - id, state, date, submitter name, subject,
the commit message (mail addresses elided) and the diff."""
import json
import re
import sys

with open(sys.argv[1]) as f:
    p = json.load(f)
sub = p.get("submitter") or {}
print(f"{p['id']} {p['state']} {p['date']} {sub.get('name')} | {p['name']}")
print(f"commit_ref: {p.get('commit_ref')}")
body = p.get("content") or ""
print(re.sub(r"<?[\w.+-]+@[\w-]+\.[\w.-]+>?", "<address>", body))
print(p.get("diff") or "")

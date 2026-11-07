#!/usr/bin/env python3
"""Read a Launchpad bug through api.launchpad.net (anonymous, read only):
the bug, its tasks, its messages and its attachment list; save the JSON
under <outdir>/bug-<n>/ and print title, description, tasks, messages
and attachment titles. Attachments themselves are not downloaded.

Usage: lp-bug.py <bug number> <outdir>
"""
import json
import sys
import urllib.request
from pathlib import Path

API = "https://api.launchpad.net/devel"
n, out = sys.argv[1], Path(sys.argv[2]) / f"bug-{sys.argv[1]}"
out.mkdir(parents=True, exist_ok=False)


def get(url, name):
    print("read:", url)
    req = urllib.request.Request(url, headers={"User-Agent": "packaging-review (read only)"})
    with urllib.request.urlopen(req, timeout=120) as r:
        data = json.loads(r.read())
    (out / f"{name}.json").write_text(json.dumps(data, indent=1))
    return data


bug = get(f"{API}/bugs/{n}", "bug")
print("title:", bug["title"])
print("created:", bug["date_created"], "| last message:", bug.get("date_last_message"))
print("heat:", bug.get("heat"), "| users affected:", bug.get("users_affected_count"),
      "| duplicates:", bug.get("number_of_duplicates"))
print("tags:", bug.get("tags"))
print("--- description ---")
print(bug["description"])
tasks = get(bug["bug_tasks_collection_link"], "tasks")
print("--- tasks ---")
for t in tasks["entries"]:
    print(t["bug_target_name"], "|", t["status"], "|", t["importance"], "|", t.get("date_closed"))
msgs = get(bug["messages_collection_link"] + "?ws.size=300", "messages")
print(f"--- messages ({len(msgs['entries'])}) ---")
for i, m in enumerate(msgs["entries"]):
    print(f"[{i}] {m['date_created']} {m['owner_link'].rsplit('/', 1)[-1]}")
    print(m["content"])
    print()
att = get(bug["attachments_collection_link"] + "?ws.size=300", "attachments")
print(f"--- attachments ({len(att['entries'])}) ---")
for a in att["entries"]:
    print(a["title"], "|", a.get("type"), "|", a["data_link"])

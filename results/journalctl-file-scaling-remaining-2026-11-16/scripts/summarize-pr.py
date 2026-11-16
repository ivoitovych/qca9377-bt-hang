#!/usr/bin/env python3
"""summarize-pr.py DIR : plain-text digest of the downloaded PR JSON (read only data)."""
import json
import sys

D = sys.argv[1]
ld = lambda n: json.load(open(f"{D}/{n}"))
p = ld("pull.json")
print("title:", p["title"], "| state:", p["state"], "| merged:", p.get("merged"), "| draft:", p.get("draft"))
print("author:", p["user"]["login"], "| created:", p["created_at"], "| updated:", p["updated_at"], "| closed:", p.get("closed_at"))
print("head:", p["head"]["sha"], p["head"]["ref"], "| base:", p["base"]["ref"], p["base"]["sha"])
print("commits:", p["commits"], "additions:", p["additions"], "deletions:", p["deletions"], "changed files:", p["changed_files"])
print("labels:", [l["name"] for l in p["labels"]])
print("\n== PR body ==\n" + (p["body"] or ""))
print("\n== commits ==")
for c in ld("commits.json"):
    print(c["sha"], c["commit"]["committer"]["date"], c["commit"]["message"].split("\n")[0])
print("\n== files ==")
for f in ld("files.json"):
    print(f["filename"], "+%d -%d" % (f["additions"], f["deletions"]))
print("\n== reviews ==")
for r in ld("reviews.json"):
    print(f"[{r['submitted_at']}] {r['user']['login']} {r['state']} (commit {r.get('commit_id','')[:10]})")
    if r["body"]:
        print(r["body"])
print("\n== inline review comments ==")
for c in ld("review-comments.json"):
    print(f"[{c['created_at']}] {c['user']['login']} on {c['path']}:{c.get('line') or c.get('original_line')} (commit {c['commit_id'][:10]}, reply_to {c.get('in_reply_to_id')})")
    print(c["body"])
    print("-" * 20)
print("\n== issue comments ==")
for c in ld("issue-comments.json"):
    print(f"[{c['created_at']}] {c['user']['login']}")
    print(c["body"])
    print("-" * 20)
print("\n== events ==")
for e in ld("events.json"):
    print(e["created_at"], e["event"], (e.get("actor") or {}).get("login"), e.get("commit_id", "") or "")

#!/usr/bin/env python3
"""bluez-human-ci-mentions.py — in the comments the survey cached
(tmp/patchwork/survey/comments-*.json), every NON-bot comment that mentions the
CI, the bot, checkpatch, gitlint or a line-length/tab complaint: who said it and
the sentence. Answers "does the maintainer ask contributors to fix what the bot
flagged?" from the record. Read-only; run bluez-accepted-survey.py first.
"""
import glob, json, os, re

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY = re.compile(r"checkpatch|gitlint|\bCI\b|test ?bot|lint|hard tab|line length|75 char|72 char|too long", re.I)
n = hits = 0
for f in sorted(glob.glob(os.path.join(REPO, "tmp/patchwork/survey/comments-*.json"))):
    for c in json.load(open(f)):
        mail = (c["submitter"].get("email") or "").lower()
        if "bot" in mail:
            continue
        n += 1
        body = "\n".join(l for l in c.get("content", "").splitlines() if not l.startswith(">"))
        for m in KEY.finditer(body):
            s = body[max(0, m.start() - 160): m.end() + 200].replace("\n", " ")
            hits += 1
            print(f"{c['date'][:10]}  {c['submitter'].get('name')}  [{os.path.basename(f)}]\n    …{s}…\n")
            break
print(f"non-bot comments scanned: {n}   mentioning CI/lint: {hits}")

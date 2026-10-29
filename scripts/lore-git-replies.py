#!/usr/bin/env python3
"""lore-git-replies.py: replies on a lore list to the mails we sent.

    lore-git-replies.py <bare git dir of a lore list epoch> [--since YYYY-MM-DD]

Reads every Message-ID in docs/sent-mails.tsv, then walks the archive's commits (one mail
each, the raw message in "m"; get the archive with scripts/lore-git-message.sh, which keeps
cache/lore-<list>-<epoch>.git) and prints each mail whose In-Reply-To or References names one
of ours, and that is not from us: date, author, subject, and which of our mails it answers.
Read-only.
"""
import email
import email.policy
import os
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OURS_FROM = "yaroslav.voytovych@gmail.com"

gitdir = sys.argv[1]
since = sys.argv[sys.argv.index("--since") + 1] if "--since" in sys.argv else None

ours = {}
with open(os.path.join(REPO, "docs", "sent-mails.tsv"), encoding="utf-8") as f:
    next(f)
    for line in f:
        cols = line.rstrip("\n").split("\t")
        if len(cols) > 3 and cols[3].startswith("<"):
            ours[cols[3].strip()] = cols[1]

args = ["git", "-C", gitdir, "log", "--format=%H", "master"]
if since:
    args.append("--since=" + since)
commits = subprocess.run(args, capture_output=True, text=True, check=True).stdout.split()
found = 0
for c in commits:
    raw = subprocess.run(["git", "-C", gitdir, "cat-file", "blob", c + ":m"],
                         capture_output=True).stdout
    msg = email.message_from_bytes(raw, policy=email.policy.compat32)
    refs = " ".join(str(msg.get(h, "")) for h in ("In-Reply-To", "References"))
    hits = [mid for mid in ours if mid in refs]
    if not hits or OURS_FROM in str(msg.get("From", "")):
        continue
    found += 1
    print("%s | %s | %s" % (msg.get("Date"), msg.get("From"), " ".join(str(msg.get("Subject", "")).split())))
    print("    Message-ID %s; answers: %s" % (msg.get("Message-ID"), "; ".join(sorted({ours[h] for h in hits}))))
print("%d repl%s to our mails among %d archived mails%s" % (
    found, "y" if found == 1 else "ies", len(commits), " since " + since if since else ""))

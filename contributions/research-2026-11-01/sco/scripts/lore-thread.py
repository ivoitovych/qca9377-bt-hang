#!/usr/bin/env python3
"""List messages in a lore git archive whose References/In-Reply-To or
Message-ID contain one of the given strings.

Usage: lore-thread.py <bare lore repo> <since YYYY-MM-DD> <needle>...
Prints: lore commit, Date, From name (no address), Message-ID, Subject.
"""
import email
import email.policy
import re
import subprocess
import sys


def git(repo, *args):
    return subprocess.run(["git", "-C", repo, *args], check=True,
                          capture_output=True).stdout


def main(repo, since, needles):
    commits = git(repo, "log", "--format=%H", f"--since={since}", "master").decode().split()
    hits = 0
    for c in reversed(commits):
        raw = git(repo, "show", f"{c}:m")
        msg = email.message_from_bytes(raw, policy=email.policy.compat32)
        refs = " ".join(str(msg.get(h, "")) for h in ("References", "In-Reply-To", "Message-ID"))
        if not any(n in refs for n in needles):
            continue
        hits += 1
        frm = str(msg.get("From", ""))
        frm = re.sub(r"<[^>]*>", "", frm).strip().strip('"')
        subj = " ".join(str(msg.get("Subject", "")).split())
        print(f"{c[:12]}  {msg.get('Date')}  {frm}  {msg.get('Message-ID')}  {subj}")
    print(f"-- {hits} messages of {len(commits)} since {since}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3:])

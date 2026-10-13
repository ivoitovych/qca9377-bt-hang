#!/usr/bin/env python3
"""unpushed-survey.py: what in these git trees exists only on this disk?

Usage: unpushed-survey.py <dir>...   (each a git work tree; or a parent: its children are taken)

Per tree: branch, uncommitted changes (tracked modified / untracked, ignored files excluded),
and commits reachable from HEAD that no remote-tracking ref contains.
"""
import os
import subprocess
import sys


def git(tree, *args):
    p = subprocess.run(["git", "-C", tree, *args], capture_output=True, text=True)
    return p.stdout.strip() if p.returncode == 0 else None


def trees(args):
    for a in args:
        if os.path.exists(os.path.join(a, ".git")):
            yield a
        else:
            for n in sorted(os.listdir(a)):
                p = os.path.join(a, n)
                if os.path.exists(os.path.join(p, ".git")):
                    yield p


def main(argv):
    print(f"{'tree':58} {'branch':42} {'modified':>8} {'untracked':>9} {'local-only commits':>18}")
    for t in trees(argv):
        branch = git(t, "rev-parse", "--abbrev-ref", "HEAD") or "?"
        status = git(t, "status", "--porcelain") or ""
        lines = [l for l in status.splitlines() if l]
        modified = sum(1 for l in lines if not l.startswith("??"))
        untracked = sum(1 for l in lines if l.startswith("??"))
        local = git(t, "rev-list", "--count", "HEAD", "--not", "--remotes")
        print(f"{t:58} {branch[:42]:42} {modified:8} {untracked:9} {local if local is not None else '?':>18}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

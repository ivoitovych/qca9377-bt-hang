#!/usr/bin/python3 -I
"""In a (sparse) worktree, for each stable branch: detach at its tip,
`git cherry-pick --no-commit` the given commits in order, record OK/CONFLICT,
the files touched and the added USB_DEVICE lines, then reset. No build.

Usage: stable-cherry-pick-check.py <worktree> <out.tsv> <commit,commit,...> <branch> [<branch>...]
"""
import subprocess
import sys

WT, OUT, COMMITS = sys.argv[1], sys.argv[2], sys.argv[3].split(",")
BRANCHES = sys.argv[4:]


def git(*a, check=False):
    return subprocess.run(["git", "-C", WT, *a], capture_output=True, text=True,
                          check=check)


rows = []
for br in BRANCHES:
    git("cherry-pick", "--abort")
    git("reset", "--hard", "-q")
    git("checkout", "-q", "--detach", br, check=True)
    tip = git("log", "-1", "--format=%h %s", br).stdout.strip()
    status, detail = "OK", ""
    for c in COMMITS:
        r = git("cherry-pick", "--no-commit", c)
        if r.returncode != 0:
            status = f"CONFLICT at {c}"
            detail = (r.stdout + r.stderr).strip().replace("\n", " ")[:300]
            break
    files = git("diff", "--cached", "--name-only", "HEAD").stdout.split()
    added = [l[1:].strip() for l in git("diff", "--cached", "-U0", "HEAD").stdout.splitlines()
             if l.startswith("+") and "USB_DEVICE" in l]
    rows.append([br, tip, status, ",".join(files), " ; ".join(added), detail])
    git("cherry-pick", "--abort")
    git("reset", "--hard", "-q")
with open(OUT, "w") as f:
    f.write("branch\ttip\tresult\tfiles\tadded_entries\tdetail\n")
    for r in rows:
        f.write("\t".join(r) + "\n")
for r in rows:
    print("\t".join(r[:5]), file=sys.stderr)

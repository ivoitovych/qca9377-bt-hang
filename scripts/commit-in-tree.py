#!/usr/bin/env python3
"""commit-in-tree.py — is a commit's change already in a source tree that has no shared history?

    python3 -I scripts/commit-in-tree.py <repo> <tree dir> <base rev> <commit> [<commit> ...]

For each commit (read from <repo>), per file it touches: how many of the lines it adds occur in
that file under <tree dir>. Only lines that were NOT already in the file at <base rev> count (the
version the tree started from: v7.0 for Ubuntu's linux-hwe-7.0 source), so common lines that
occur elsewhere in the file do not make an absent commit look present. Blank lines, lone braces
and comment-only lines are skipped. Verdict per commit: PRESENT (all such lines found), ABSENT
(none), PARTIAL (some: a reworked backport, a later change, or moved context; read the diff).
Built for distribution trees (Ubuntu's source is v7.0 plus a diff, so `git log` cannot answer
it). Read-only. Positive control: the same commits against a stable worktree that has them.
Exit 0; 2 on a usage error.
"""
import os
import subprocess
import sys

TRIVIAL = {"", "{", "}", "};", "else", "else {", "} else {", "return;", "break;", "*/", "/*"}


def informative(line):
    s = line.strip()
    return s not in TRIVIAL and not s.startswith(("//", "* ", "/* ")) and s != "*"


def git(repo, *args):
    return subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True)


def added_lines(repo, commit):
    out = git(repo, "show", "--format=%h %s", "-U0", commit)
    out.check_returncode()
    lines = out.stdout.splitlines()
    files, cur = {}, None
    for line in lines[1:]:
        if line.startswith("+++ "):
            cur = line[6:] if line.startswith("+++ b/") else None
            if cur:
                files.setdefault(cur, [])
        elif cur and line.startswith("+") and informative(line[1:]):
            files[cur].append(line[1:].strip())
    return lines[0], files


def main(args):
    if len(args) < 4:
        print(__doc__.strip().splitlines()[2].strip(), file=sys.stderr)
        return 2
    repo, tree, base, commits = args[0], args[1], args[2], args[3:]
    for c in commits:
        head, files = added_lines(repo, c)
        print(head)
        verdicts = []
        for path, added in files.items():
            old = git(repo, "show", f"{base}:{path}")
            known = {l.strip() for l in old.stdout.splitlines()} if old.returncode == 0 else set()
            new = [l for l in added if l not in known]
            try:
                with open(os.path.join(tree, path), errors="replace") as f:
                    have = {l.strip() for l in f}
            except OSError:
                print(f"    {path}: no such file in the tree -> ABSENT")
                verdicts.append("ABSENT")
                continue
            if not new:
                print(f"    {path}: every added line was already in {base}; cannot tell")
                verdicts.append("UNKNOWN")
                continue
            found = sum(1 for l in new if l in have)
            v = "PRESENT" if found == len(new) else "ABSENT" if found == 0 else "PARTIAL"
            verdicts.append(v)
            print(f"    {path}: {found}/{len(new)} new lines found -> {v}")
        print(f"  => {verdicts[0] if len(set(verdicts)) == 1 else 'PARTIAL'}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

#!/usr/bin/env python3
"""export-local-work.py: save what exists only in local upstream source trees.

Usage: export-local-work.py <out-dir> <tree>...

For each tree (a kernel, BlueZ or other upstream checkout under cache/), writes into
<out-dir>/<tree name>/:
  NNNN-*.patch       git format-patch of every commit reachable from HEAD that no
                     remote-tracking ref contains (our local work), oldest first
  uncommitted.diff   git diff HEAD (tracked changes not committed), when any
  untracked/...      untracked files up to 1 MB each, copied with their paths
  untracked-skipped.txt  untracked files over 1 MB, listed, not copied
  BASE.txt           the tree's path, branch, HEAD, the upstream commit the patches
                     apply to, and how to re-apply them
Refuses to write into an existing <out-dir>/<tree name>.
"""
import os
import shutil
import subprocess
import sys

LIMIT = 1 << 20


def git(tree, *args, text=True):
    p = subprocess.run(["git", "-C", tree, *args], capture_output=True, text=text)
    return p.stdout if p.returncode == 0 else None


def export(out_root, tree):
    name = os.path.basename(tree.rstrip("/"))
    out = os.path.join(out_root, name)
    if os.path.exists(out):
        raise SystemExit(f"{out} exists; refusing to overwrite")
    local = (git(tree, "rev-list", "--reverse", "HEAD", "--not", "--remotes") or "").split()
    diff = git(tree, "diff", "HEAD") or ""
    untracked = (git(tree, "ls-files", "--others", "--exclude-standard") or "").splitlines()
    if not local and not diff and not untracked:
        print(f"{name}: nothing local")
        return
    os.makedirs(out)
    base = git(tree, "rev-parse", f"{local[0]}^").strip() if local else git(tree, "rev-parse", "HEAD").strip()
    if local:
        git(tree, "format-patch", "-q", "-o", out, f"{base}..HEAD")
    if diff:
        with open(os.path.join(out, "uncommitted.diff"), "w", encoding="utf-8") as f:
            f.write(diff)
    skipped = []
    for rel in untracked:
        src = os.path.join(tree, rel)
        if not os.path.isfile(src):
            continue
        if os.path.getsize(src) > LIMIT:
            skipped.append(f"{rel}\t{os.path.getsize(src)} bytes")
            continue
        dst = os.path.join(out, "untracked", rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)
    if skipped:
        with open(os.path.join(out, "untracked-skipped.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(skipped) + "\n")
    branch = (git(tree, "rev-parse", "--abbrev-ref", "HEAD") or "?").strip()
    head = (git(tree, "rev-parse", "HEAD") or "?").strip()
    subject = (git(tree, "log", "-1", "--format=%s", base) or "").strip()
    with open(os.path.join(out, "BASE.txt"), "w", encoding="utf-8") as f:
        f.write(f"tree:    {tree}\nbranch:  {branch}\nHEAD:    {head}\n"
                f"base:    {base}  {subject}\n"
                f"commits: {len(local)} local-only (the NNNN-*.patch files)\n"
                f"uncommitted diff: {'yes' if diff else 'no'}\n"
                f"untracked: {len(untracked)} file(s), {len(skipped)} over 1 MB not copied\n\n"
                f"Re-apply: git checkout {base} && git am NNNN-*.patch "
                f"&& git apply uncommitted.diff\n")
    print(f"{name}: {len(local)} commit(s), diff {'yes' if diff else 'no'}, "
          f"{len(untracked)} untracked ({len(skipped)} skipped)")


def main(argv):
    out_root, trees = argv[0], argv[1:]
    os.makedirs(out_root, exist_ok=True)
    for t in trees:
        export(out_root, t)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

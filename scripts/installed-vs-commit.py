#!/usr/bin/env python3
"""Read-only: compare every file an install.sh installs with the blob it came from.

usage: installed-vs-commit.py <repo> <installed-commit> [<candidate-commit>]

Parses <installed-commit>:install.sh for `install_file "$SRC/<src>" <dst>` lines
(backslash continuations joined), hashes each <dst> on this machine as git does, and
compares it with <installed-commit>:<src>. With a candidate commit, also says whether a
deploy of that commit would change the file. Writes nothing.
"""
import hashlib
import re
import subprocess
import sys


def git(repo, *args):
    return subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True)


def blob_of(repo, commit, path):
    r = git(repo, "rev-parse", f"{commit}:{path}")
    return r.stdout.strip() if r.returncode == 0 else None


def hash_file(path):
    try:
        with open(path, "rb") as f:
            data = f.read()
    except FileNotFoundError:
        return "missing"
    except PermissionError:
        return "unreadable"
    return hashlib.sha1(b"blob %d\0" % len(data) + data).hexdigest()


def main():
    if len(sys.argv) not in (3, 4):
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    repo, old = sys.argv[1], sys.argv[2]
    new = sys.argv[3] if len(sys.argv) == 4 else None
    r = git(repo, "show", f"{old}:install.sh")
    if r.returncode != 0:
        print(f"cannot read {old}:install.sh: {r.stderr.strip()}", file=sys.stderr)
        return 2
    text = re.sub(r"\\\n\s*", " ", r.stdout)
    pairs = re.findall(r'install_file\s+"\$SRC/([^"]+)"\s+(\S+)', text)
    seen = set()
    counts = {}
    for src, dst in pairs:
        if dst in seen:
            continue
        seen.add(dst)
        want = blob_of(repo, old, src)
        have = hash_file(dst)
        if have in ("missing", "unreadable"):
            verdict = have
        elif want is None:
            verdict = "no-source-in-commit"
        else:
            verdict = "identical" if have == want else "DIFFERS"
        change = ""
        if new:
            nb = blob_of(repo, new, src)
            change = "  deploy: " + ("unchanged" if nb == want else ("changes" if nb else "source gone"))
        counts[verdict] = counts.get(verdict, 0) + 1
        print(f"{verdict:20} {dst}  <- {src}{change}")
    print()
    print(f"{len(seen)} destinations from {old}:install.sh: "
          + ", ".join(f"{v} {k}" for k, v in sorted(counts.items())))
    return 0 if set(counts) == {"identical"} else 1


if __name__ == "__main__":
    sys.exit(main())

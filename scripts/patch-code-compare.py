#!/usr/bin/env python3
"""patch-code-compare.py — is the CODE in two sets of patch mails the same?

For reworded mails (new commit messages, a new base, regenerated hashes): proves the code did not
move, so the tests run on one set still apply to the other.

  python3 -I scripts/patch-code-compare.py <dir A> <dir B>

Pairs the mails by number (0001-…, 0002-…; the 0000 cover letter has no code and is skipped) and
checks each pair two independent ways:
  1. the diff text itself, from the first "diff --git" line to the mail signature, with only the
     "index <blob>..<blob>" lines left out (they name blobs of the tree, which change with the
     base). Every changed line, file name and hunk header is compared. A difference is printed
     as a unified diff;
  2. `git patch-id --stable`, git's own fingerprint of a patch's code (it ignores the message,
     hashes and line numbers, not the content).
It also says whether the message (subject and body) differs, for information.

Exit 0: every pair has identical code by both methods. Exit 1: a difference (printed). Exit 2:
the sets do not pair up (different counts or numbers). Read-only.
"""
import difflib
import os
import re
import subprocess
import sys


def mails(d):
    out = {}
    for f in sorted(os.listdir(d)):
        m = re.match(r"(\d{4})-.*\.patch$", f)
        if m and m.group(1) != "0000":
            out[m.group(1)] = os.path.join(d, f)
    return out


def split(path):
    text = open(path, encoding="utf-8").read()
    lines = text.split("\n")
    start = next((i for i, l in enumerate(lines) if l.startswith("diff --git ")), None)
    if start is None:
        sys.exit(f"{path}: no 'diff --git' line")
    end = next((i for i in range(len(lines) - 1, start, -1) if lines[i] == "-- "), len(lines))
    code = [l for l in lines[start:end] if not l.startswith("index ")]
    subject = next((l for l in lines if l.startswith("Subject: ")), "")
    msg_start = next(i for i, l in enumerate(lines) if l == "") + 1
    msg_end = next(i for i in range(msg_start, len(lines)) if lines[i] == "---")
    message = [subject] + lines[msg_start:msg_end]
    return code, message, text


def patch_id(text):
    r = subprocess.run(["git", "patch-id", "--stable"], input=text, capture_output=True,
                       text=True, check=True)
    return r.stdout.split()[0] if r.stdout.strip() else "(none)"


def main(argv):
    if len(argv) != 3:
        sys.exit(__doc__)
    a, b = mails(argv[1]), mails(argv[2])
    if not a or a.keys() != b.keys():
        print(f"the sets do not pair up: {sorted(a)} vs {sorted(b)}")
        return 2
    same_all = True
    for n in sorted(a):
        ca, ma, ta = split(a[n])
        cb, mb, tb = split(b[n])
        pa, pb = patch_id(ta), patch_id(tb)
        text_same, id_same = ca == cb, pa == pb
        same_all &= text_same and id_same
        print(f"{n}  {os.path.basename(a[n])}")
        print(f"      code text: {'IDENTICAL' if text_same else 'DIFFERS'} "
              f"({len(ca)} lines compared, index lines left out)")
        print(f"      patch-id : {'IDENTICAL' if id_same else 'DIFFERS'}  {pa[:16]} / {pb[:16]}")
        print(f"      message  : {'same' if ma == mb else 'changed'}")
        if not text_same:
            for l in difflib.unified_diff(ca, cb, "A", "B", lineterm="", n=2):
                print("        " + l)
    print("RESULT: the code is identical in every pair" if same_all else
          "RESULT: the code DIFFERS (above)")
    return 0 if same_all else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))

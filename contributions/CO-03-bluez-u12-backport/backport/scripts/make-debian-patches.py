#!/usr/bin/env python3
"""Write each commit of the CO-03 branch (base..branch) as a debian/patches
entry with a DEP-3 header, into <out dir>, and print the series lines.

Usage: make-debian-patches.py <tree> <base> <branch> <out dir>
"""
import re
import subprocess
import sys
from pathlib import Path

tree, base, branch, out = sys.argv[1:5]
out = Path(out)
out.mkdir(parents=True, exist_ok=True)

GITWEB = "https://git.kernel.org/pub/scm/bluetooth/bluez.git/commit/?id="
# Upstream release that first carries each commit (git describe --contains
# in the upstream checkout); None: in master, not yet released.
RELEASE = {
    "a734b06059cbe0d0f00442c901506ef17e960960": None,
    "0bed9886cff317d814f9b1f11c1461459f2b9a00": None,
    "3d9900eb754d277ef6abf21bed827cdc9e79ddb4": "5.79",
    "a14d59725ef35d91b8504770046c701d0a2efe07": "5.80",
    "664a5d3785a1a57989d236b6fd649321a39451f5": "5.80",
}
LAST_UPDATE = "2026-10-31"


def git(*args):
    return subprocess.run(["git", "-C", tree, *args], check=True,
                          stdout=subprocess.PIPE, encoding="utf-8").stdout


commits = git("rev-list", "--reverse", f"{base}..{branch}").split()
names = []
for i, c in enumerate(commits, 1):
    subject = git("log", "-1", "--format=%s", c).strip()
    body = git("log", "-1", "--format=%b", c).rstrip()
    author = git("log", "-1", "--format=%an <%ae>", c).strip()
    m = re.search(r"\(backported from commit ([0-9a-f]{40})\)", body)
    if not m:
        sys.exit(f"{c}: no backport note")
    up = m.group(1)
    rel = RELEASE[up]

    desc_body = []
    for line in body.split("\n"):
        desc_body.append(" " + line if line.strip() else " .")
    hdr = [f"Description: {subject}"] + desc_body
    hdr.append(f"Author: {author}")
    # "backport" when the commit carries an adaptation note: a "[...]"
    # line right after the "(backported from commit ...)" line
    after = body.split(m.group(0), 1)[1].lstrip("\n")
    origin = "backport" if after.startswith("[") else "upstream"
    hdr.append(f"Origin: {origin}, {GITWEB}{up}")
    if rel:
        hdr.append(f"Applied-Upstream: {rel}, commit:{up}")
    else:
        hdr.append(f"Applied-Upstream: commit:{up}")
    hdr.append(f"Last-Update: {LAST_UPDATE}")
    hdr.append("---")

    diff = git("show", "--format=", "--no-color", "--stat", "-p", c)
    slug = re.sub(r"[^A-Za-z0-9]+", "-", subject).strip("-")
    name = f"co03-{i:02d}-{slug}.patch"
    (out / name).write_text("\n".join(hdr) + "\n" + diff)
    names.append(name)

for n in names:
    print(n)

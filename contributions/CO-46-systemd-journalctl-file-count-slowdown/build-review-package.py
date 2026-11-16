#!/usr/bin/env python3
"""build-review-package.py OUT — the CO-46 noble SRU review package as one markdown file.

The review request first, then every file of sru-noble/ under its path, each in a fence.
Then a check of the bundle for words that must not be in a self-contained package: this
project's name, local paths and OPEN markers (listed below), and the private wording list
that devtools/repo-scan also reads (../private-config/publish-wording.txt beside the main
checkout, or BT_PRIVATE_WORDING; kept out of the repository because a public list would
publish its words). Every hit is printed, nothing is changed. Exit 1 on any hit, 2 when the
private list cannot be read (the bundle is then NOT CHECKED, not clean).
"""
import os
import pathlib
import re
import subprocess
import sys

CO = pathlib.Path(__file__).resolve().parent
PKG = CO / "sru-noble"
ORDER = [
    "README.md",
    "bug-description.md",
    "evidence.md",
    "reproducer/journalctl-file-scaling-repro.sh",
    "reproducer/output.txt",
    "reproducer/Dockerfile",
    "reproducer/inside-repro-test.sh",
]
BANNED = [
    r"qca9377", r"bt-hang", r"bluetooth", r"\bCO-\d+", r"/root\b", r"<work dir>",
    r"\[OPEN", r"operator", r"\bour project\b", r"\bthe laptop\b",
]


def private_wording():
    """The private list's patterns, or None when it cannot be read."""
    path = os.environ.get("BT_PRIVATE_WORDING")
    if not path:
        try:
            common = subprocess.run(
                ["git", "-C", str(CO), "rev-parse", "--path-format=absolute", "--git-common-dir"],
                capture_output=True, text=True, check=True,
            ).stdout.strip()
        except (OSError, subprocess.CalledProcessError):
            return None
        path = str(pathlib.Path(common).parent.parent / "private-config" / "publish-wording.txt")
    try:
        lines = pathlib.Path(path).read_text().splitlines()
    except OSError:
        return None
    pats = [ln.strip() for ln in lines if ln.strip() and not ln.lstrip().startswith("#")]
    return pats or None


def fence(text):
    n = 3
    while "`" * n in text:
        n += 1
    return "`" * n


def main():
    out = pathlib.Path(sys.argv[1])
    files = ORDER + sorted(
        str(p.relative_to(PKG)) for p in PKG.rglob("*") if p.is_file() and str(p.relative_to(PKG)) not in ORDER
    )
    parts = [(CO / "sru-noble-review-request.md").read_text()]
    for rel in files:
        text = (PKG / rel).read_text()
        f = fence(text)
        lang = "diff" if rel.endswith((".patch", ".diff", ".debdiff")) else ""
        parts.append(f"\n## `{rel}`\n\n{f}{lang}\n{text.rstrip()}\n{f}\n")
    bundle = "\n".join(parts)
    out.write_text(bundle)
    private = private_wording()
    hits = 0
    for i, line in enumerate(bundle.splitlines(), 1):
        for pat in BANNED:
            if re.search(pat, line):
                print(f"{out}:{i}: [{pat}] {line.strip()[:160]}")
                hits += 1
        for pat in private or []:
            if re.search(pat, line):
                print(f"{out}:{i}: [private list] {line.strip()[:160]}")
                hits += 1
    print(f"{len(files) + 1} files, {len(bundle.splitlines())} lines, {hits} hit(s) -> {out}")
    if hits:
        return 1
    if private is None:
        print("NOT CHECKED against the private wording list: it could not be read", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())

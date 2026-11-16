#!/usr/bin/env python3
"""build-review-package.py OUT — the CO-46 noble SRU review package as one markdown file.

The review request first, then every file of sru-noble/ under its path, each in a fence.
Then a check of the bundle for words that must not be in a self-contained package (this
project's name, local paths, tool names, OPEN markers); every hit is printed, nothing is
changed. Exit 1 on any hit.
"""
import pathlib
import re
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
    r"qca9377", r"bt-hang", r"bluetooth", r"\bCO-\d+", r"/root\b", r"agent-work", r"<work dir>",
    r"[Cc]laude", r"Anthropic", r"Sonnet", r"Opus", r"Haiku", r"\bAI\b", r"compaction",
    r"\[OPEN", r"operator", r"\bour project\b", r"\bthe laptop\b",
]


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
    hits = 0
    for i, line in enumerate(bundle.splitlines(), 1):
        for pat in BANNED:
            if re.search(pat, line):
                print(f"{out}:{i}: [{pat}] {line.strip()[:160]}")
                hits += 1
    print(f"{len(files) + 1} files, {len(bundle.splitlines())} lines, {hits} hit(s) -> {out}")
    return 1 if hits else 0


if __name__ == "__main__":
    sys.exit(main())

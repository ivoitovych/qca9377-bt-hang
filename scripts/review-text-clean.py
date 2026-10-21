#!/usr/bin/env python3
"""Clean an outside reviewer's text for the public reviews/ directory.

Usage: python3 -I scripts/review-text-clean.py <in.md> <out.md> [<header.md>]

With <header.md>, its text is written first, followed by a "---" line.

Removes what the reviewer's tooling added and what must not be published,
and nothing else:
  - citation markers such as "fileciteturn0file0L1-L2" and
    "citeturn14view0turn14view1";
  - "utm_source" tracking parameters in links;
  - favicon image lines and the site-name line that follows each one;
  - the HTML space entity "&#x20;";
  - links whose URL carries a mail address (plain or %40-encoded), which
    become "[link removed: it carries a mail address]".
Prints how many of each it removed. Refuses to overwrite <out.md>.
"""
import os
import re
import sys


def main():
    if len(sys.argv) not in (3, 4):
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    src, dst = sys.argv[1], sys.argv[2]
    header = ""
    if len(sys.argv) == 4:
        with open(sys.argv[3], encoding="utf-8") as f:
            header = f.read().rstrip("\n") + "\n\n---\n\n"
    if os.path.exists(dst):
        print(f"refusing to overwrite {dst}", file=sys.stderr)
        return 2
    with open(src, encoding="utf-8") as f:
        lines = f.read().split("\n")

    counts = {"citation": 0, "tracking": 0, "favicon": 0, "entity": 0, "mail-link": 0}
    out = []
    # After a favicon line the tooling prints up to two short label lines
    # (the site name, then sometimes "+1"); they are skipped with it.
    skip_labels = 0
    for line in lines:
        if re.match(r"^\s*\[image\]\(https://www\.google\.com/s2/favicons", line):
            counts["favicon"] += 1
            skip_labels = 2
            continue
        if skip_labels:
            stripped = line.strip()
            if stripped == "":
                continue
            if len(stripped) < 40 and "(" not in stripped:
                skip_labels -= 1
                continue
            skip_labels = 0
        # The tooling wraps each marker in private-use characters:
        # U+E200 "filecite" U+E202 "turn0file0" [U+E202 "L1-L2"] U+E201.
        line, n = re.subn("\\s?\ue200(?:file)?cite[^\ue201]*\ue201", "", line)
        counts["citation"] += n
        line, n = re.subn(r"\s?(?:file)?cite(?:turn\w+)+(?:L\d+-L\d+)?", "", line)
        counts["citation"] += n
        line, n = re.subn(r"\?utm_source=[^)\s]*", "", line)
        counts["tracking"] += n
        line, n = re.subn(r"&#x20;", "", line)
        counts["entity"] += n
        line, n = re.subn(r"\[([^\]]*)\]\((https?://[^)\s]*(?:@|%40)[^)\s]*)\)",
                          r"\1 [link removed: it carries a mail address]", line)
        counts["mail-link"] += n
        out.append(line)

    with open(dst, "x", encoding="utf-8") as f:
        f.write(header + "\n".join(out))
    for key, value in counts.items():
        print(f"{key}: {value}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

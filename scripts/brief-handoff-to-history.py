#!/usr/bin/env python3
"""Move BRIEF.md's hand-off block, verbatim, to the end of HISTORY.md.

Usage: scripts/brief-handoff-to-history.py <date> <placeholder>

The block is the run of lines starting with '> **HAND-OFF' up to the last
'>'-prefixed line before the next blank line. It is appended to HISTORY.md
under '## BRIEF hand-off block as it stood on <date> (moved verbatim;
replaced by a fresh block)' and replaced in BRIEF.md by the single line
<placeholder>, for the fresh block to be written over it.
"""
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
date, placeholder = sys.argv[1], sys.argv[2]
brief = (root / "BRIEF.md").read_text().split("\n")

start = next(i for i, l in enumerate(brief) if l.startswith("> **HAND-OFF"))
end = start
while end + 1 < len(brief) and brief[end + 1].startswith(">"):
    end += 1
block = brief[start:end + 1]

history = root / "HISTORY.md"
text = history.read_text().rstrip("\n")
text += ("\n\n## BRIEF hand-off block as it stood on " + date +
         " (moved verbatim; replaced by a fresh block)\n\n" + "\n".join(block) + "\n")
history.write_text(text)

brief[start:end + 1] = [placeholder]
(root / "BRIEF.md").write_text("\n".join(brief))
print(f"moved BRIEF.md lines {start + 1}-{end + 1} ({len(block)} lines) to HISTORY.md")
